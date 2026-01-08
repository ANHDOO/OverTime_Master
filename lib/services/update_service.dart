import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service để kiểm tra và tải bản cập nhật từ Google Drive
class UpdateService {
  /// FILE_ID của file metadata.json trên Google Drive
  /// 
  /// Cách lấy FILE_ID:
  /// 1. Upload file metadata.json lên Google Drive (folder: https://drive.google.com/drive/u/0/folders/1NjHCrZyZohQnRptgZL62G7LUTEFL66YY)
  /// 2. Right-click vào file -> Share -> "Change to anyone with the link" -> Viewer
  /// 3. Copy link share (ví dụ: https://drive.google.com/file/d/FILE_ID_HERE/view?usp=sharing)
  /// 4. FILE_ID là phần giữa /d/ và /view
  /// 
  /// Format file metadata.json:
  /// {
  ///   "versionCode": 2,
  ///   "versionName": "1.0.1",
  ///   "downloadUrl": "https://drive.google.com/uc?export=download&id=APK_FILE_ID",
  ///   "changelog": "Cập nhật mới...",
  ///   "fileSize": "25 MB"
  /// }
  /// 
  /// Lưu ý: File phải được share public (Anyone with the link can view)
  static const String METADATA_FILE_ID = '17HnOQ3CKafJ6IF4H_KIMerxpo8-Lrzuw';
  
  /// Lấy URL download từ Google Drive (thử nhiều format)
  String _getMetadataUrl() {
    // Format 1: Direct download link (nếu file public)
    final url1 = 'https://drive.google.com/uc?export=download&id=$METADATA_FILE_ID';
    // Format 2: View link để lấy direct download (cho file nhỏ < 25MB)
    final url2 = 'https://drive.google.com/uc?export=view&id=$METADATA_FILE_ID';
    // Format 3: Dùng format cho file được share public
    final url3 = 'https://docs.google.com/uc?export=download&id=$METADATA_FILE_ID';
    
    // Thử format 1 trước (phổ biến nhất)
    return '$url1&t=${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Fetch metadata với retry và error handling tốt hơn
  Future<Map<String, dynamic>?> _fetchMetadata() async {
    final List<String> urls = [
      'https://drive.google.com/uc?export=download&id=$METADATA_FILE_ID',
      'https://drive.google.com/uc?export=view&id=$METADATA_FILE_ID',
      'https://docs.google.com/uc?export=download&id=$METADATA_FILE_ID',
    ];
    
    final client = http.Client();
    
    try {
      for (int i = 0; i < urls.length; i++) {
        try {
          final url = '${urls[i]}&t=${DateTime.now().millisecondsSinceEpoch}';
          debugPrint('🔄 Attempting to fetch metadata (attempt ${i + 1}/${urls.length}): $url');
          
          var response = await client.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'application/json, text/plain, */*',
            },
          ).timeout(const Duration(seconds: 10));
          
          // Handle redirects manually if needed (though http.get usually handles them)
          if (response.statusCode == 302 || response.statusCode == 301) {
            final location = response.headers['location'];
            if (location != null) {
              debugPrint('↪️ Redirecting to: $location');
              response = await client.get(Uri.parse(location)).timeout(const Duration(seconds: 10));
            }
          }

          final bodyText = utf8.decode(response.bodyBytes);
          debugPrint('📡 Response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            final body = bodyText.trim();
            
            // Check if it's a Google Drive virus scan warning page
            if (body.contains('download_warning') || body.contains('confirm=') || body.contains('Google Drive - Quét virus')) {
              debugPrint('⚠️ Google Drive warning page detected. Attempting to bypass...');
              
              // Try to extract the confirmation token
              final match = RegExp(r'confirm=([a-zA-Z0-9_]+)').firstMatch(body);
              if (match != null) {
                final token = match.group(1);
                final bypassUrl = '$url&confirm=$token';
                debugPrint('🔄 Bypassing with token: $token');
                response = await client.get(Uri.parse(bypassUrl)).timeout(const Duration(seconds: 10));
                final bypassedBody = utf8.decode(response.bodyBytes).trim();
                
                if (bypassedBody.startsWith('{') && bypassedBody.endsWith('}')) {
                  return json.decode(bypassedBody) as Map<String, dynamic>;
                }
              }
            }

            if (body.startsWith('{') && body.endsWith('}')) {
              try {
                final metadata = json.decode(body) as Map<String, dynamic>;
                debugPrint('✅ Successfully parsed metadata JSON');
                return metadata;
              } catch (e) {
                debugPrint('❌ Failed to parse JSON: $e');
                debugPrint('📡 Raw body (first 200 chars): ${body.substring(0, min(200, body.length))}');
              }
            } else {
              debugPrint('⚠️ Response is not JSON. Starts with: ${body.substring(0, min(100, body.length))}');
            }
          } else {
            debugPrint('❌ HTTP error ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('❌ Error fetching from URL ${i + 1}: $e');
        }
      }
    } finally {
      client.close();
    }
    
    return null;
  }
  
  /// Kiểm tra xem có bản cập nhật mới không
  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      // Lấy thông tin version hiện tại
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.parse(packageInfo.buildNumber);
      final currentVersionName = packageInfo.version;

      debugPrint('📱 Current app version: $currentVersionName (build $currentVersionCode)');
      debugPrint('📱 PackageInfo details:');
      debugPrint('   - version: ${packageInfo.version}');
      debugPrint('   - buildNumber: ${packageInfo.buildNumber}');
      debugPrint('   - appName: ${packageInfo.appName}');
      debugPrint('   - packageName: ${packageInfo.packageName}');
      
      // Fetch metadata từ Drive
      final metadata = await _fetchMetadata();
      
      if (metadata == null) {
        debugPrint('❌ Failed to fetch metadata from Google Drive');
        return UpdateCheckResult(
          hasUpdate: false,
          error: 'Không thể kết nối đến Google Drive. Vui lòng kiểm tra:\n'
                 '1. Kết nối internet\n'
                 '2. File metadata.json có tồn tại và được share public\n'
                 '3. File ID trong code có đúng không',
        );
      }
      
      // Parse metadata
      try {
        final remoteVersionCode = metadata['versionCode'] as int?;
        final remoteVersionName = metadata['versionName'] as String?;
        final downloadUrl = metadata['downloadUrl'] as String?;
        
        if (remoteVersionCode == null || remoteVersionName == null || downloadUrl == null) {
          return UpdateCheckResult(
            hasUpdate: false,
            error: 'File metadata không đúng định dạng. Thiếu các trường: versionCode, versionName, downloadUrl',
          );
        }
        
        final changelog = metadata['changelog'] as String? ?? '';
        final fileSize = metadata['fileSize'] as String? ?? '';
        
        debugPrint('🌐 Remote version: $remoteVersionName (build $remoteVersionCode)');
        debugPrint('📦 Download URL: $downloadUrl');
        debugPrint('🔍 Comparing versions:');
        debugPrint('   - Current build: $currentVersionCode');
        debugPrint('   - Remote build: $remoteVersionCode');
        debugPrint('   - Comparison: $remoteVersionCode > $currentVersionCode = ${remoteVersionCode > currentVersionCode}');

        // So sánh version code
        if (remoteVersionCode > currentVersionCode) {
          debugPrint('✨ New version available!');
          return UpdateCheckResult(
            hasUpdate: true,
            updateInfo: UpdateInfo(
              versionName: remoteVersionName,
              versionCode: remoteVersionCode,
              downloadUrl: downloadUrl,
              changelog: changelog,
              fileSize: fileSize,
            ),
          );
        } else {
          debugPrint('✅ App is up to date');
          return UpdateCheckResult(
            hasUpdate: false,
            error: null,
          );
        }
      } catch (e) {
        debugPrint('❌ Error parsing metadata: $e');
        return UpdateCheckResult(
          hasUpdate: false,
          error: 'Lỗi khi đọc thông tin phiên bản: $e',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking for update: $e');
      debugPrint('Stack trace: $stackTrace');
      return UpdateCheckResult(
        hasUpdate: false,
        error: 'Lỗi không xác định: $e',
      );
    }
  }
  
  int min(int a, int b) => a < b ? a : b;
  
  /// Tải APK về và cài đặt với thanh tiến trình và xử lý cảnh báo Drive
  Future<bool> downloadAndInstall(String downloadUrl, BuildContext context) async {
    final navigator = Navigator.of(context);
    final ValueNotifier<double> progressNotifier = ValueNotifier(0);
    
    try {
      // 0. Kiểm tra quyền cài đặt (Android)
      if (Platform.isAndroid) {
        debugPrint('🛡️ Checking install packages permission...');
        var status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          debugPrint('🛡️ Requesting install packages permission...');
          status = await Permission.requestInstallPackages.request();
          if (!status.isGranted) {
            debugPrint('❌ Install permission denied');
            _showError(context, 'Bạn cần cấp quyền "Cài đặt ứng dụng không rõ nguồn gốc" để thực hiện cập nhật.');
            return false;
          }
        }
      }

      // Hiển thị dialog tiến trình
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, child) {
            return AlertDialog(
              title: const Text('Đang tải bản cập nhật'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress > 0 ? progress : null),
                  const SizedBox(height: 16),
                  Text(progress > 0 
                    ? 'Đã tải: ${(progress * 100).toStringAsFixed(1)}%' 
                    : 'Đang chuẩn bị tải...'),
                ],
              ),
            );
          },
        ),
      );
      
      final client = http.Client();
      String finalUrl = downloadUrl;
      
      // 1. Kiểm tra xem có bị chặn bởi trang cảnh báo không
      debugPrint('🔍 Checking download URL for Drive warnings: $finalUrl');
      var headResponse = await client.get(
        Uri.parse(finalUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Head response status: ${headResponse.statusCode}');
      final headBody = utf8.decode(headResponse.bodyBytes);
      
      if (headResponse.statusCode == 200) {
        if (headBody.contains('download_warning') || headBody.contains('confirm=') || headBody.contains('Google Drive - Quét virus') || headBody.contains('confirm')) {
          debugPrint('⚠️ Download blocked by Drive warning. Attempting bypass...');
          
          // Try to extract the confirmation token using a more robust regex
          final match = RegExp(r'confirm=([a-zA-Z0-9_]+)').firstMatch(headBody);
          if (match != null) {
            final token = match.group(1);
            final separator = finalUrl.contains('?') ? '&' : '?';
            finalUrl = '$finalUrl${separator}confirm=$token';
            debugPrint('🔄 Bypassing with token: $token');
          } else {
            // Fallback: Try adding confirm=t if token not found (sometimes works)
            final separator = finalUrl.contains('?') ? '&' : '?';
            finalUrl = '$finalUrl${separator}confirm=t';
            debugPrint('🔄 Token not found, trying fallback confirm=t');
          }
        }
      }

      // 2. Bắt đầu tải thực sự
      debugPrint('📥 Starting actual download from: $finalUrl');
      final request = http.Request('GET', Uri.parse(finalUrl));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
      
      final response = await client.send(request).timeout(const Duration(seconds: 20));
      
      if (response.statusCode != 200) {
        navigator.pop(); // Đóng progress dialog
        _showError(context, 'Không thể tải file. Mã lỗi: ${response.statusCode}');
        client.close();
        return false;
      }
      
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/overtime_update.apk');
      final sink = file.openWrite();
      
      bool isFirstChunk = true;
      await for (final chunk in response.stream) {
        if (isFirstChunk) {
          isFirstChunk = false;
          // Check for ZIP magic bytes (PK..) which APKs use
          if (chunk.length >= 2) {
            if (chunk[0] != 0x50 || chunk[1] != 0x4B) {
              debugPrint('❌ WARNING: Downloaded file does not look like an APK (ZIP). First bytes: ${chunk.sublist(0, min(10, chunk.length))}');
              // If it looks like HTML (starts with <), it's probably a Drive error page
              if (chunk[0] == 0x3C) {
                final htmlSnippet = utf8.decode(chunk.sublist(0, min(200, chunk.length)), allowMalformed: true);
                debugPrint('❌ Detected HTML content: $htmlSnippet');
                
                // If we are here, it means our pre-check failed. Let's try to extract token from this chunk
                final match = RegExp(r'confirm=([a-zA-Z0-9_]+)').firstMatch(htmlSnippet);
                if (match != null) {
                  debugPrint('💡 Found token in stream! Need to restart download with token.');
                  // This is complex to handle mid-stream, but we can at least log it.
                }
              }
            } else {
              debugPrint('✅ Verified APK magic bytes (PK)');
            }
          }
        }
        
        receivedBytes += chunk.length;
        sink.add(chunk);
        
        if (totalBytes > 0) {
          progressNotifier.value = receivedBytes / totalBytes;
        }
      }
      
      await sink.close();
      client.close();
      
      debugPrint('✅ Download completed. Total size: $receivedBytes bytes');
      
      navigator.pop(); // Đóng progress dialog
      
      // Mở file để cài đặt
      debugPrint('🚀 Opening file for installation: ${file.path}');
      final result = await OpenFile.open(file.path);
      debugPrint('🚀 OpenFile result: ${result.type} - ${result.message}');
      
      if (result.type != ResultType.done && result.type != ResultType.noAppToOpen) {
        _showError(context, 'Không thể mở file cài đặt (${result.type}). Vui lòng cài đặt thủ công từ thư mục Download.');
        return false;
      }
      
      return true;
    } catch (e) {
      try { navigator.pop(); } catch (_) {}
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

/// Kết quả kiểm tra cập nhật
class UpdateCheckResult {
  final bool hasUpdate;
  final UpdateInfo? updateInfo;
  final String? error;
  
  UpdateCheckResult({
    required this.hasUpdate,
    this.updateInfo,
    this.error,
  });
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
