import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service để kiểm tra và tải bản cập nhật từ Google Drive
class UpdateService {
  // URL metadata.json trên Google Drive (file latest_metadata.json trong root folder)
  // Thay đổi FILE_ID này sau khi upload metadata.json lên Drive
  static const String METADATA_URL = 
      'https://drive.google.com/uc?export=download&id=17HnOQ3CKafJ6IF4H_KIMerxpo8-Lrzuw';
  
  /// Kiểm tra xem có bản cập nhật mới không
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Lấy thông tin version hiện tại
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      final currentVersionName = packageInfo.version;
      
      debugPrint('Current version: $currentVersionName ($currentVersionCode)');
      
      // Fetch metadata từ Drive (thêm timestamp để tránh cache)
      final requestUrl = '$METADATA_URL&t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http.get(Uri.parse(requestUrl));
      
      if (response.statusCode != 200) {
        debugPrint('Failed to fetch metadata: ${response.statusCode}');
        return null;
      }
      
      final metadata = json.decode(response.body) as Map<String, dynamic>;
      final remoteVersionCode = metadata['versionCode'] as int;
      final remoteVersionName = metadata['versionName'] as String;
      final downloadUrl = metadata['downloadUrl'] as String;
      final changelog = metadata['changelog'] as String? ?? '';
      
      debugPrint('Remote version: $remoteVersionName ($remoteVersionCode)');
      
      // So sánh version code
      if (remoteVersionCode > currentVersionCode) {
        return UpdateInfo(
          versionName: remoteVersionName,
          versionCode: remoteVersionCode,
          downloadUrl: downloadUrl,
          changelog: changelog,
          fileSize: metadata['fileSize'] as String? ?? '',
        );
      }
      
      return null; // Không có bản mới
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return null;
    }
  }
  
  /// Tải APK về và cài đặt
  Future<bool> downloadAndInstall(String downloadUrl, BuildContext context) async {
    try {
      // Hiển thị dialog loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Tải file về
      final response = await http.Client().send(http.Request('GET', Uri.parse(downloadUrl)));
      
      if (response.statusCode != 200) {
        Navigator.of(context).pop(); // Đóng loading dialog
        _showError(context, 'Không thể tải file. Mã lỗi: ${response.statusCode}');
        return false;
      }
      
      // Lưu file vào thư mục tạm
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/overtime_update.apk');
      
      final sink = file.openWrite();
      await response.stream.pipe(sink);
      await sink.close();
      
      Navigator.of(context).pop(); // Đóng loading dialog
      
      // Mở file để cài đặt
      // Android sẽ tự động xử lý quyền cài đặt khi mở file
      final result = await OpenFile.open(file.path);
      
      if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
        _showError(context, 'Không thể mở file cài đặt. Vui lòng cài đặt thủ công từ file manager.');
        return false;
      }
      
      return true;
    } catch (e) {
      Navigator.of(context).pop(); // Đóng loading dialog nếu có
      debugPrint('Error downloading update: $e');
      _showError(context, 'Lỗi khi tải bản cập nhật: $e');
      return false;
    }
  }
  
  void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lỗi'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  
  /// Hiển thị dialog cập nhật
  Future<bool?> showUpdateDialog(BuildContext context, UpdateInfo updateInfo) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Có bản cập nhật mới'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phiên bản mới: ${updateInfo.versionName}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (updateInfo.fileSize.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Kích thước: ${updateInfo.fileSize}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
              if (updateInfo.changelog.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Thay đổi:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  updateInfo.changelog,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bỏ qua'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tải về'),
          ),
        ],
      ),
    );
  }
}

/// Thông tin về bản cập nhật
class UpdateInfo {
  final String versionName;
  final int versionCode;
  final String downloadUrl;
  final String changelog;
  final String fileSize;
  
  UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.downloadUrl,
    required this.changelog,
    required this.fileSize,
  });
}
