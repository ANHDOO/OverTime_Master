import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';

/// Trạng thái tải bản cập nhật
enum DownloadStatus { idle, checking, downloading, readyToInstall, error }

/// Service để kiểm tra và tải bản cập nhật (Singleton + ChangeNotifier)
class UpdateService extends ChangeNotifier {
  // Singleton pattern
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // URL chứa thông tin metadata trên GitHub
  static const String METADATA_URL = 'https://raw.githubusercontent.com/ANHDOO/OverTime_Master/main/metadata.json';

  // Trạng thái quản lý
  DownloadStatus _status = DownloadStatus.idle;
  double _progress = 0;
  String? _error;
  UpdateInfo? _updateInfo;
  String? _downloadedFilePath;

  DownloadStatus get status => _status;
  double get progress => _progress;
  String? get error => _error;
  UpdateInfo? get updateInfo => _updateInfo;
  bool get hasUpdate => _updateInfo != null;
  String? get downloadedFilePath => _downloadedFilePath;

  final Dio _dio = Dio();

  /// Reset trạng thái
  void reset() {
    _status = DownloadStatus.idle;
    _progress = 0;
    _error = null;
    _downloadedFilePath = null;
    notifyListeners();
  }

  /// Kiểm tra xem có bản cập nhật mới không
  Future<UpdateCheckResult> checkForUpdate() async {
    _status = DownloadStatus.checking;
    notifyListeners();

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      final currentVersionName = packageInfo.version;

      final metadata = await _fetchMetadata();
      
      debugPrint('🔍 Current Version: $currentVersionName (Build $currentVersionCode)');
      
      if (metadata == null) {
        _status = DownloadStatus.error;
        _error = 'Không thể lấy thông tin cập nhật.';
        notifyListeners();
        return UpdateCheckResult(hasUpdate: false, error: _error);
      }

      final remoteVersionCode = metadata['versionCode'] as int?;
      final remoteVersionName = metadata['versionName'] as String?;
      final downloadUrl = metadata['downloadUrl'] as String?;
      
      if (remoteVersionCode == null || remoteVersionName == null || downloadUrl == null) {
        _status = DownloadStatus.error;
        _error = 'Metadata không hợp lệ.';
        notifyListeners();
        return UpdateCheckResult(hasUpdate: false, error: _error);
      }

      _updateInfo = UpdateInfo(
        versionName: remoteVersionName,
        versionCode: remoteVersionCode,
        downloadUrl: downloadUrl,
        changelog: metadata['changelog'] as String? ?? '',
        fileSize: metadata['fileSize'] as String? ?? '',
      );

      bool hasNewerName = _isNewerVersion(remoteVersionName, currentVersionName);
      bool hasNewerBuild = false;
      if (!hasNewerName && remoteVersionName == currentVersionName) {
        hasNewerBuild = remoteVersionCode > currentVersionCode;
      }

      final resultHasUpdate = hasNewerName || hasNewerBuild;
      debugPrint('📢 Update Result: $resultHasUpdate (Remote: $remoteVersionName Build $remoteVersionCode)');
      
      _status = resultHasUpdate ? DownloadStatus.idle : DownloadStatus.idle;
      if (!resultHasUpdate) {
        _updateInfo = null;
      }
      
      notifyListeners();
      return UpdateCheckResult(hasUpdate: resultHasUpdate, updateInfo: _updateInfo);
    } catch (e) {
      _status = DownloadStatus.error;
      _error = e.toString();
      notifyListeners();
      return UpdateCheckResult(hasUpdate: false, error: _error);
    }
  }

  /// Tải bản cập nhật ngầm
  Future<void> downloadInBackground() async {
    if (_updateInfo == null || _status == DownloadStatus.downloading) return;

    _status = DownloadStatus.downloading;
    _progress = 0;
    _error = null;
    notifyListeners();

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/overtime_update_${_updateInfo!.versionName}.apk';
      
      String downloadUrl = _updateInfo!.downloadUrl;
      
      // Danh sách proxy ưu tiên cho GitHub tại Việt Nam
      List<String> downloadUrls = [
        'https://ghproxy.net/$downloadUrl',
        'https://gh-proxy.com/$downloadUrl',
        'https://mirror.ghproxy.com/$downloadUrl',
        downloadUrl, // Link gốc
      ];

      bool success = false;
      String? lastError;

      for (var url in downloadUrls) {
        try {
          debugPrint('🚀 Phóng link tải: $url');
          await _dio.download(
            url,
            savePath,
            onReceiveProgress: (received, total) {
              if (total != -1) {
                _progress = received / total;
                notifyListeners();
              }
            },
            options: Options(
              headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
              followRedirects: true,
              sendTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 5),
              validateStatus: (status) => status != null && status < 400,
            ),
          );
          success = true;
          break;
        } catch (e) {
          debugPrint('⚠️ Lỗi với nguồn $url: $e');
          lastError = e.toString();
        }
      }

      if (success) {
        _downloadedFilePath = savePath;
        _status = DownloadStatus.readyToInstall;
      } else {
        _status = DownloadStatus.error;
        _error = 'Không thể tải bản cập nhật từ bất kỳ nguồn nào: $lastError';
      }
      notifyListeners();
    } catch (e) {
      _status = DownloadStatus.error;
      _error = 'Lỗi hệ thống: $e';
      notifyListeners();
    }
  }

  /// Thực hiện cài đặt
  Future<bool> installUpdate() async {
    if (_downloadedFilePath == null) return false;

    if (Platform.isAndroid) {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) return false;
      }
    }

    final result = await OpenFile.open(_downloadedFilePath, type: "application/vnd.android.package-archive");
    return result.type == ResultType.done;
  }

  Future<Map<String, dynamic>?> _fetchMetadata() async {
    try {
      // Thêm timestamp để bypass cache của GitHub Raw
      final urlWithCacheBuster = '$METADATA_URL?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(urlWithCacheBuster));
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        debugPrint('✅ Metadata fetched: ${json.encode(data)}');
        return data;
      } else {
        debugPrint('❌ Fetch metadata failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching metadata: $e');
    }
    return null;
  }

  bool _isNewerVersion(String remote, String current) {
    try {
      final r = remote.startsWith('v') ? remote.substring(1) : remote;
      final c = current.startsWith('v') ? current.substring(1) : current;
      List<int> rp = r.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> cp = c.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < (rp.length > cp.length ? rp.length : cp.length); i++) {
        int rv = i < rp.length ? rp[i] : 0;
        int cv = i < cp.length ? cp[i] : 0;
        if (rv > cv) return true;
        if (rv < cv) return false;
      }
    } catch (_) {}
    return false;
  }

  // Tiện ích hiển thị thông báo
  Future<bool?> showUpdateDialog(BuildContext context, UpdateInfo updateInfo) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Có bản cập nhật mới'),
        content: Text('Phiên bản: ${updateInfo.versionName}\n${updateInfo.changelog}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bỏ qua')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tải về')),
        ],
      ),
    );
  }
}

class UpdateCheckResult {
  final bool hasUpdate;
  final UpdateInfo? updateInfo;
  final String? error;
  UpdateCheckResult({required this.hasUpdate, this.updateInfo, this.error});
}

class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String changelog;
  final String fileSize;
  UpdateInfo({required this.versionName, required this.versionCode, required this.downloadUrl, required this.changelog, required this.fileSize});
}
