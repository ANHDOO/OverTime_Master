import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/google_sheets_service.dart';
import '../../providers/overtime_provider.dart';
import '../../theme/app_theme.dart';

class GoogleSheetsScreen extends StatefulWidget {
  const GoogleSheetsScreen({super.key});

  @override
  State<GoogleSheetsScreen> createState() => _GoogleSheetsScreenState();
}

class _GoogleSheetsScreenState extends State<GoogleSheetsScreen> {
  String _status = '';
  bool _isSyncing = false;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _checkGoogleSignInStatus();
  }

  Future<void> _checkGoogleSignInStatus() async {
    final service = GoogleSheetsService();
    final isSignedIn = await service.isSignedInWithGoogle();
    if (mounted) {
      setState(() {
        _isSignedIn = isSignedIn;
      });
    }
  }


  Future<void> _syncAll() async {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    setState(() {
      _isSyncing = true;
      _status = 'Đang đồng bộ...';
    });
    await provider.syncAllProjectsToSheets();
    if (mounted) {
      setState(() {
        _isSyncing = false;
        _status = 'Đã đồng bộ xong';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Đã đồng bộ tất cả dự án!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sheets')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with sync status
            _buildHeader(isDark),
            const SizedBox(height: 20),
            
            // Google Sign-In Status
            if (_isSignedIn) ...[
              
              _buildSyncActions(isDark),
              const SizedBox(height: 24),
              
              // Synced Projects List
              _buildSyncedProjects(isDark),
            ] else ...[
              _buildSignInPrompt(isDark),
            ],
            
            const SizedBox(height: 16),
            if (_status.isNotEmpty) _buildStatusIndicator(isDark),
          ],
        ),
      ),
    );
  }


  Widget _buildSyncActions(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
        borderRadius: AppRadius.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Đồng bộ dữ liệu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _syncAll,
                  icon: _isSyncing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.cloud_upload_rounded),
                  label: Text(_isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ tất cả'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _openGoogleSheets,
                icon: Icon(Icons.open_in_new_rounded),
                label: Text('Mở Sheets'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedProjects(bool isDark) {
    return FutureBuilder<List<String>>(
      future: _getSyncedProjects(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
            borderRadius: AppRadius.borderLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_rounded, color: AppColors.tealPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Dự án đã đồng bộ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${projects.length} dự án',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (projects.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có dự án nào được đồng bộ',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...projects.map((project) => _buildProjectItem(project, isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectItem(String projectName, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              projectName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
          const SizedBox(height: 12),
          Text(
            'Chưa đăng nhập Google',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng đăng nhập Google từ Menu bên trái để sử dụng tính năng đồng bộ Google Sheets.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<String>> _getSyncedProjects() async {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    final projects = provider.cashTransactions
        .map((t) => t.project)
        .where((p) => p != 'Mặc định')
        .toSet()
        .toList();
    return projects;
  }

  Future<void> _openGoogleSheets() async {
    final sheetsService = GoogleSheetsService();
    final spreadsheetId = await sheetsService.getSpreadsheetId();
    
    if (spreadsheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có trang tính nào được tạo')),
      );
      return;
    }

    final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/edit';
    
    // Note: url_launcher was removed, so we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link: $url'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'COPY',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url)).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã sao chép liên kết vào bộ nhớ tạm')),
              );
            });
          },
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withOpacity(isDark ? 0.15 : 0.1),
            AppColors.successDark.withOpacity(isDark ? 0.1 : 0.05),
          ],
        ),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(Icons.table_chart_rounded, color: AppColors.success, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đồng bộ Google Sheets',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dữ liệu được lưu vào file "OverTime Master - Quỹ Dự Án"',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _status.contains('xong')
              ? AppColors.success.withOpacity(isDark ? 0.2 : 0.1)
              : AppColors.info.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: AppRadius.borderFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_status.contains('xong'))
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16)
            else
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AppColors.info, strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(
              _status,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
