import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/backup_service.dart';
import '../../services/google_sheets_service.dart';
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
  bool _isInitializing = true;
  List<Map<String, dynamic>> _backupList = [];
  Map<String, dynamic>? _lastBackupInfo;
  Map<String, dynamic>? _lastRestoreInfo;

  // Keys backup state
  bool _hasSheetsKeys = false;
  Map<String, dynamic>? _lastKeysBackupInfo;
  Map<String, dynamic>? _lastKeysRestoreInfo;
  List<Map<String, dynamic>> _keysBackupList = [];

  @override
  void initState() {
    super.initState();
    _backupService.addListener(_onBackupServiceChanged);
    _initializeBackupService();
  }

  @override
  void dispose() {
    _backupService.removeListener(_onBackupServiceChanged);
    super.dispose();
  }

  void _onBackupServiceChanged() {
    if (mounted) {
      setState(() {
        _isSignedIn = _backupService.isSignedInValue;
      });
      if (_isSignedIn && _backupList.isEmpty) {
        _loadBackupData();
      }
    }
  }

  Future<void> _initializeBackupService() async {
    try {
      await _backupService.initializeGoogleSignIn();
      
      // Check if already signed in
      final signedIn = await _backupService.isSignedIn();
      if (signedIn) {
        // Restore session silently to initialize Drive API
        await _backupService.signInSilently();
        _isSignedIn = _backupService.isSignedInValue;
        if (_isSignedIn) {
          await _loadBackupData();
        }
      }
    } catch (e) {
      debugPrint('Backup init error: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  Future<void> _loadBackupData() async {
    try {
      _backupList = await _backupService.getBackupList();
      _lastBackupInfo = await _backupService.getLastBackupInfo();
      _lastRestoreInfo = await _backupService.getLastRestoreInfo();

      // Load keys data
      final sheetsService = GoogleSheetsService();
      _hasSheetsKeys = await sheetsService.hasKeys();
      _lastKeysBackupInfo = await _backupService.getLastKeysBackupInfo();
      _lastKeysRestoreInfo = await _backupService.getLastKeysRestoreInfo();
      _keysBackupList = await _backupService.getKeysBackupList();

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

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    
    // Allow loading overlay to render before heavy operations
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    
    try {
      final success = await _backupService.restoreDatabase(backupFileId: fileId);
      if (!mounted) return;
      
      if (success) {
        // Auto-restore Google Sheets keys too
        final keysSuccess = await _backupService.restoreSheetsKeys();
        if (!mounted) return;
        
        // Reload provider from disk to reflect restored DB immediately
        try {
          final provider = Provider.of<OvertimeProvider>(context, listen: false);
          await provider.reloadFromDisk();
        } catch (e) {
          debugPrint('Error reloading provider after restore: $e');
        }
        if (!mounted) return;
        
        await _loadBackupData();
        if (!mounted) return;
        
        // Show success message after all operations complete
        if (keysSuccess) {
          _showSuccess('Khôi phục database và keys thành công!');
        } else {
          _showSuccess('Khôi phục database thành công!');
        }
      } else {
        _showError('Khôi phục thất bại');
      }
    } catch (e) {
      if (mounted) {
        _showError('Lỗi khôi phục: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        bottom: _isInitializing
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
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

                  // Google Sheets Keys Backup
                  _buildKeysBackupSection(),

                  const SizedBox(height: 24),

                  // Last Backup Info
                  if (_lastBackupInfo != null) _buildLastBackupInfo(),

                  const SizedBox(height: 24),

                  // Last Restore Info
                  if (_lastRestoreInfo != null) _buildLastRestoreInfo(),

                  const SizedBox(height: 24),

                  // Backup List
                  _buildBackupList(),
                ] else if (!_isInitializing) ...[
                  // Show a hint if not signed in and not initializing
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      'Vui lòng đăng nhập để xem danh sách sao lưu',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
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

  Widget _buildKeysBackupSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Google Sheets Keys',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _hasSheetsKeys ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasSheetsKeys ? Icons.check_circle : Icons.warning,
                        size: 16,
                        color: _hasSheetsKeys ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasSheetsKeys ? 'Đã cấu hình' : 'Chưa có keys',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasSheetsKeys ? Colors.green[800] : Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _hasSheetsKeys
                  ? 'Keys Google Sheets của bạn đã được cấu hình. Keys sẽ được tự động backup khi bạn sync dữ liệu.'
                  : 'Bạn chưa cấu hình Google Sheets. Hãy thiết lập trong phần Cài đặt Google Sheets.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (_hasSheetsKeys) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _backupSheetsKeys,
                      icon: const Icon(Icons.backup, size: 16),
                      label: const Text('Backup Keys'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _restoreSheetsKeys,
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore Keys'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_lastKeysBackupInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.backup, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keys đã backup: ${_formatDateTime(_lastKeysBackupInfo!['timestamp'])}',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_lastKeysRestoreInfo != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.restore, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Keys đã khôi phục: ${_formatDateTime(_lastKeysRestoreInfo!['timestamp'])}',
                        style: TextStyle(fontSize: 12, color: Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _backupSheetsKeys() async {
    setState(() => _isLoading = true);
    try {
      final success = await _backupService.backupSheetsKeys();
      if (success) {
        _showSuccess('Backup Google Sheets keys thành công');
        await _loadBackupData();
      } else {
        _showError('Backup Google Sheets keys thất bại');
      }
    } catch (e) {
      _showError('Lỗi backup keys: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreSheetsKeys() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận khôi phục Keys'),
        content: const Text(
          'Keys Google Sheets hiện tại sẽ bị ghi đè. Bạn có chắc chắn muốn khôi phục?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final success = await _backupService.restoreSheetsKeys();
      if (success) {
        _showSuccess('Khôi phục Google Sheets keys thành công');
        await _loadBackupData();
      } else {
        _showError('Khôi phục Google Sheets keys thất bại');
      }
    } catch (e) {
      _showError('Lỗi khôi phục keys: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
