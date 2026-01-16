import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/services/backup_service.dart';
import 'package:provider/provider.dart';
import '../../../logic/providers/overtime_provider.dart';
import '../../../logic/providers/debt_provider.dart';
import '../../../logic/providers/cash_transaction_provider.dart';
import '../../../logic/providers/citizen_profile_provider.dart';
import '../../../logic/providers/gold_provider.dart';
import '../../../core/theme/app_theme.dart';

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
      setState(() => _isSignedIn = _backupService.isSignedInValue);
      if (_isSignedIn && _backupList.isEmpty) _loadBackupData();
    }
  }

  Future<void> _initializeBackupService() async {
    try {
      await _backupService.initializeGoogleSignIn();
      final signedIn = await _backupService.isSignedIn();
      if (signedIn) {
        await _backupService.signInSilently();
        _isSignedIn = _backupService.isSignedInValue;
        if (_isSignedIn) await _loadBackupData();
      }
    } catch (e) {
      debugPrint('Backup init error: $e');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
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



  Future<void> _backupDatabase() async {
    setState(() => _isLoading = true);
    try {
      final results = await _backupService.backupAll();
      if (results['database'] == true) {
        _showSuccess(results['sheets_keys'] == true ? 'Sao lưu toàn bộ thành công!' : 'Sao lưu database thành công (Keys thất bại)');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Xác nhận khôi phục', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: Text('Dữ liệu hiện tại sẽ bị ghi đè. Bạn có chắc chắn?', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Khôi phục', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;

    try {
      final results = await _backupService.restoreAll(backupFileId: fileId);
      if (!mounted) return;
      if (results['database'] == true) {
        try {
          await Provider.of<OvertimeProvider>(context, listen: false).reloadFromDisk();
          await Provider.of<DebtProvider>(context, listen: false).fetchDebtEntries();
          await Provider.of<CashTransactionProvider>(context, listen: false).fetchCashTransactions();
          await Provider.of<CitizenProfileProvider>(context, listen: false).fetchCitizenProfiles();
          await Provider.of<GoldProvider>(context, listen: false).fetchGoldData();
        } catch (e) {
          debugPrint('Error reloading provider after restore: $e');
        }
        if (!mounted) return;
        await _loadBackupData();
        if (!mounted) return;
        _showSuccess(results['sheets_keys'] == true ? 'Khôi phục toàn bộ thành công!' : 'Khôi phục database thành công (Keys thất bại)');
      } else {
        _showError('Khôi phục thất bại');
      }
    } catch (e) {
      if (mounted) _showError('Lỗi khôi phục: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(String fileId, String fileName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Xóa bản sao lưu?', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: Text('Bạn có chắc muốn xóa "$fileName"?', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.white), const SizedBox(width: 12), Flexible(child: Text(message))]),
        backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ));
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white), const SizedBox(width: 12), Flexible(child: Text(message))]),
        backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ));
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

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

  String _formatCreatedTime(dynamic createdTime) {
    if (createdTime == null) return '-';
    try {
      if (createdTime is DateTime) return DateFormat('dd/MM/yyyy HH:mm').format(createdTime);
      if (createdTime is String) {
        final parsed = DateTime.tryParse(createdTime);
        if (parsed != null) return DateFormat('dd/MM/yyyy HH:mm').format(parsed);
      }
      return createdTime.toString();
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sao lưu & Khôi phục'),
        bottom: _isInitializing ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadBackupData,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator (no login button - use Side Menu)
                  _buildConnectionStatus(isDark),
                  if (_isSignedIn) ...[
                    const SizedBox(height: 20),
                    _buildBackupActions(isDark),
                    if (_lastBackupInfo != null) ...[const SizedBox(height: 20), _buildLastBackupInfo(isDark)],
                    if (_lastRestoreInfo != null) ...[const SizedBox(height: 20), _buildLastRestoreInfo(isDark)],
                    const SizedBox(height: 20),
                    _buildBackupList(isDark),
                  ] else if (!_isInitializing) ...[
                    const SizedBox(height: 60),
                    Center(child: Column(
                      children: [
                        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant, shape: BoxShape.circle), child: Icon(Icons.cloud_off_rounded, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        const SizedBox(height: 20),
                        Text('Vui lòng đăng nhập Google từ Menu', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                      ],
                    )),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading) Container(color: Colors.black26, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _isSignedIn
            ? LinearGradient(colors: [AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1), AppColors.successDark.withValues(alpha: isDark ? 0.15 : 0.05)])
            : LinearGradient(colors: [AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1), AppColors.warningDark.withValues(alpha: isDark ? 0.15 : 0.05)]),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: _isSignedIn ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: (_isSignedIn ? AppColors.success : AppColors.warning).withValues(alpha: 0.2), borderRadius: AppRadius.borderMd),
            child: Icon(_isSignedIn ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: _isSignedIn ? AppColors.success : AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isSignedIn ? 'Đã kết nối Google Drive' : 'Chưa kết nối', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text(_isSignedIn ? 'Sẵn sàng sao lưu dữ liệu' : 'Đăng nhập từ Menu bên trái', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.backup_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text('Thao tác sao lưu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(gradient: AppGradients.heroBlue, borderRadius: AppRadius.borderMd),
                  child: ElevatedButton.icon(
                    onPressed: _backupDatabase,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: const Text('Sao lưu', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(gradient: AppGradients.heroGreen, borderRadius: AppRadius.borderMd),
                  child: ElevatedButton.icon(
                    onPressed: () => _restoreDatabase(),
                    icon: const Icon(Icons.cloud_download_rounded, size: 20),
                    label: const Text('Khôi phục', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastBackupInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: AppRadius.borderSm), child: Icon(Icons.backup_rounded, color: AppColors.primary, size: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lần sao lưu cuối', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text(_lastBackupInfo?['timestamp'] != null ? _formatDateTime(_lastBackupInfo!['timestamp']) : '-', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              ],
            ),
          ),
          Text(_formatFileSizeDynamic(_lastBackupInfo?['size']), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _buildLastRestoreInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.2), borderRadius: AppRadius.borderSm), child: Icon(Icons.restore_rounded, color: AppColors.success, size: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lần khôi phục cuối', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                Text(_lastRestoreInfo?['timestamp'] != null ? _formatDateTime(_lastRestoreInfo!['timestamp']) : '-', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              ],
            ),
          ),
          Text(_formatFileSizeDynamic(_lastRestoreInfo?['size']), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
        ],
      ),
    );
  }

  Widget _buildBackupList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.folder_rounded, color: AppColors.indigoPrimary, size: 20),
          const SizedBox(width: 10),
          Text('Danh sách bản sao lưu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        ]),
        const SizedBox(height: 16),
        if (_backupList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant, borderRadius: AppRadius.borderLg),
            child: Center(child: Text('Chưa có bản sao lưu nào', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          )
        else
          ..._backupList.map((backup) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(Icons.backup_rounded, color: AppColors.primary, size: 20)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(backup['name'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.access_time_rounded, size: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        const SizedBox(width: 4),
                        Text(_formatCreatedTime(backup['createdTime']), style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        const SizedBox(width: 12),
                        Text(_formatFileSizeDynamic(backup['size']), style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  onSelected: (value) {
                    if (value == 'restore') _restoreDatabase(fileId: backup['id']);
                    if (value == 'delete') _deleteBackup(backup['id'], backup['name']);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'restore', child: Row(children: [Icon(Icons.restore_rounded, size: 18, color: AppColors.success), const SizedBox(width: 10), const Text('Khôi phục')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: AppColors.danger), const SizedBox(width: 10), const Text('Xóa')])),
                  ],
                ),
              ],
            ),
          )),
      ],
    );
  }
}
