import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/backup_service.dart';
import 'package:provider/provider.dart';
import '../../providers/overtime_provider.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();
  bool _isSignedIn = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _backupList = [];
  Map<String, dynamic>? _lastBackupInfo;
  Map<String, dynamic>? _lastRestoreInfo;

  @override
  void initState() {
    super.initState();
    _initializeBackupService();
  }

  Future<void> _initializeBackupService() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.initializeGoogleSignIn();
      _isSignedIn = await _backupService.isSignedIn();
      if (_isSignedIn) {
        await _loadBackupData();
      }
    } catch (e) {
      _showError('Lỗi khởi tạo: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBackupData() async {
    try {
      _backupList = await _backupService.getBackupList();
      _lastBackupInfo = await _backupService.getLastBackupInfo();
      _lastRestoreInfo = await _backupService.getLastRestoreInfo();
      setState(() {});
    } catch (e) {
      _showError('Lỗi tải dữ liệu backup: $e');
    }
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final success = await _backupService.signIn();
      if (success) {
        _isSignedIn = true;
        await _loadBackupData();
      } else {
        _showError('Đăng nhập Google thất bại');
      }
    } catch (e) {
      _showError('Lỗi đăng nhập: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await _backupService.signOut();
      _isSignedIn = false;
      _backupList.clear();
      _lastBackupInfo = null;
      _lastRestoreInfo = null;
      setState(() {});
    } catch (e) {
      _showError('Lỗi đăng xuất: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _backupDatabase() async {
    setState(() => _isLoading = true);
    try {
      final success = await _backupService.backupDatabase();
      if (success) {
        _showSuccess('Sao lưu thành công!');
        await _loadBackupData();
      } else {
        _showError('Sao lưu thất bại');
      }
    } catch (e) {
      _showError('Lỗi sao lưu: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreDatabase({String? fileId}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận khôi phục'),
        content: const Text(
          'Dữ liệu hiện tại sẽ bị ghi đè. Bạn có chắc chắn muốn khôi phục từ bản sao lưu?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await _backupService.restoreDatabase(backupFileId: fileId);
      if (success) {
        _showSuccess('Khôi phục thành công! Đang tải lại dữ liệu...');
        // Reload provider from disk to reflect restored DB immediately
        try {
          final provider = Provider.of<OvertimeProvider>(context, listen: false);
          await provider.reloadFromDisk();
        } catch (e) {
          debugPrint('Error reloading provider after restore: $e');
        }
      } else {
        _showError('Khôi phục thất bại');
      }
    } catch (e) {
      _showError('Lỗi khôi phục: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(String fileId, String fileName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa bản sao lưu "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await _backupService.deleteBackup(fileId);
      if (success) {
        _showSuccess('Xóa bản sao lưu thành công');
        await _loadBackupData();
      } else {
        _showError('Xóa bản sao lưu thất bại');
      }
    } catch (e) {
      _showError('Lỗi xóa: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Safe formatter that accepts int, num, String or null.
  String _formatFileSizeDynamic(dynamic size) {
    if (size == null) return '-';
    try {
      if (size is int) return _formatFileSize(size);
      if (size is double) return _formatFileSize(size.toInt());
      if (size is num) return _formatFileSize(size.toInt());
      if (size is String) {
        final cleaned = size.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.isEmpty) return size;
        final parsed = int.tryParse(cleaned);
        if (parsed != null) return _formatFileSize(parsed);
        return size;
      }
      return size.toString();
    } catch (_) {
      return '-';
    }
  }

  String _formatDateTime(String isoString) {
    final dateTime = DateTime.parse(isoString);
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  // Robust formatter for createdTime which can be null, DateTime, or String
  String _formatCreatedTime(dynamic createdTime) {
    if (createdTime == null) return '-';
    try {
      if (createdTime is DateTime) {
        return DateFormat('dd/MM/yyyy HH:mm').format(createdTime);
      }
      // Some APIs return RFC3339 strings
      if (createdTime is String) {
        final parsed = DateTime.tryParse(createdTime);
        if (parsed != null) return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      }
      // Fallback to toString
      return createdTime.toString();
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Khôi phục'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Google Sign In Status
                  _buildGoogleSignInSection(),

                  if (_isSignedIn) ...[
                    const SizedBox(height: 24),

                    // Backup Actions
                    _buildBackupActions(),

                    const SizedBox(height: 24),

                    // Last Backup Info
                    if (_lastBackupInfo != null) _buildLastBackupInfo(),

                    const SizedBox(height: 24),

                    // Last Restore Info
                    if (_lastRestoreInfo != null) _buildLastRestoreInfo(),

                    const SizedBox(height: 24),

                    // Backup List
                    _buildBackupList(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildGoogleSignInSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isSignedIn ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isSignedIn ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isSignedIn ? Icons.cloud_done : Icons.cloud_off,
                color: _isSignedIn ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _isSignedIn ? 'Đã kết nối Google Drive' : 'Chưa kết nối Google Drive',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isSignedIn ? Colors.green.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isSignedIn
                ? 'Bạn có thể sao lưu và khôi phục dữ liệu lên Google Drive.'
                : 'Đăng nhập Google để sử dụng tính năng sao lưu đám mây.',
            style: TextStyle(
              color: _isSignedIn ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSignedIn ? _signOut : _signIn,
              icon: Icon(_isSignedIn ? Icons.logout : Icons.login),
              label: Text(_isSignedIn ? 'Đăng xuất' : 'Đăng nhập Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSignedIn ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thao tác sao lưu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _backupDatabase,
                  icon: const Icon(Icons.backup),
                  label: const Text('Sao lưu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _restoreDatabase(),
                  icon: const Icon(Icons.restore),
                  label: const Text('Khôi phục'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastBackupInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.backup, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Lần sao lưu cuối',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thời gian: ${_lastBackupInfo != null && _lastBackupInfo!['timestamp'] != null ? _formatDateTime(_lastBackupInfo!['timestamp']) : '-'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'Kích thước: ${_formatFileSizeDynamic(_lastBackupInfo?['size'])}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLastRestoreInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restore, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Lần khôi phục cuối',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Thời gian: ${_lastRestoreInfo != null && _lastRestoreInfo!['timestamp'] != null ? _formatDateTime(_lastRestoreInfo!['timestamp']) : '-'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            'Kích thước: ${_formatFileSizeDynamic(_lastRestoreInfo?['size'])}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Danh sách bản sao lưu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_backupList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'Chưa có bản sao lưu nào',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._backupList.map((backup) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.backup, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backup['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Tạo: ${_formatCreatedTime(backup['createdTime'])}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            'Kích thước: ${_formatFileSizeDynamic(backup['size'])}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'restore':
                            _restoreDatabase(fileId: backup['id']);
                            break;
                          case 'delete':
                            _deleteBackup(backup['id'], backup['name']);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'restore',
                          child: Row(
                            children: [
                              Icon(Icons.restore, size: 16),
                              SizedBox(width: 8),
                              Text('Khôi phục'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('Xóa'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}
