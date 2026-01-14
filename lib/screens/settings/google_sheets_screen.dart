import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/google_sheets_service.dart';
import '../../providers/overtime_provider.dart';
import '../../theme/app_theme.dart';

class GoogleSheetsScreen extends StatefulWidget {
  const GoogleSheetsScreen({super.key});

  @override
  State<GoogleSheetsScreen> createState() => _GoogleSheetsScreenState();
}

class _GoogleSheetsScreenState extends State<GoogleSheetsScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _refreshTokenController = TextEditingController();
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();
  String _status = '';
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenController.text = prefs.getString('google_sheets_access_token') ?? '';
      _refreshTokenController.text = prefs.getString('google_sheets_refresh_token') ?? '';
      _clientIdController.text = prefs.getString('google_sheets_client_id') ?? '';
      _clientSecretController.text = prefs.getString('google_sheets_client_secret') ?? '';
    });
  }

  Future<void> _saveToken() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final service = GoogleSheetsService();
    await service.setAccessToken(_tokenController.text.trim());
    await service.setRefreshToken(_refreshTokenController.text.trim());
    await service.setClientId(_clientIdController.text.trim());
    await service.setClientSecret(_clientSecretController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Đã lưu cấu hình Google Sheets!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
    }
  }

  void _smartPaste() async {
    final text = _tokenController.text;
    if (text.contains('ACCESS TOKEN:') || text.contains('REFRESH TOKEN:')) {
      _parseAndPopulate(text);
    }
  }

  void _parseAndPopulate(String text) {
    final accessTokenMatch = RegExp(r'ACCESS TOKEN:\s*([^\n\r]+)').firstMatch(text);
    final refreshTokenMatch = RegExp(r'REFRESH TOKEN:\s*([^\n\r]+)').firstMatch(text);
    final clientIdMatch = RegExp(r'CLIENT ID:\s*([^\n\r]+)').firstMatch(text);
    final clientSecretMatch = RegExp(r'CLIENT SECRET:\s*([^\n\r]+)').firstMatch(text);

    setState(() {
      if (accessTokenMatch != null) _tokenController.text = accessTokenMatch.group(1)!.trim();
      if (refreshTokenMatch != null) _refreshTokenController.text = refreshTokenMatch.group(1)!.trim();
      if (clientIdMatch != null) _clientIdController.text = clientIdMatch.group(1)!.trim();
      if (clientSecretMatch != null) _clientSecretController.text = clientSecretMatch.group(1)!.trim();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.auto_fix_high_rounded, color: Colors.white),
            const SizedBox(width: 12),
            const Text('Đã tự động điền các trường!'),
          ],
        ),
        backgroundColor: AppColors.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),
    );
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
    _tokenController.dispose();
    _refreshTokenController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
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
            _buildHeader(isDark),
            const SizedBox(height: 20),
            _buildInputField(_tokenController, 'Access Token', Icons.key_rounded, isDark, maxLines: 2, showAutoFill: true),
            const SizedBox(height: 12),
            _buildInputField(_refreshTokenController, 'Refresh Token', Icons.refresh_rounded, isDark),
            const SizedBox(height: 12),
            _buildInputField(_clientIdController, 'Client ID', Icons.badge_rounded, isDark),
            const SizedBox(height: 12),
            _buildInputField(_clientSecretController, 'Client Secret', Icons.lock_rounded, isDark, isSecret: true),
            const SizedBox(height: 24),
            _buildActionButtons(isDark),
            const SizedBox(height: 16),
            if (_status.isNotEmpty) _buildStatusIndicator(isDark),
          ],
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
                      'Cấu hình Google Sheets API',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đồng bộ dữ liệu lên Google Sheets',
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
          const SizedBox(height: 14),
          Text(
            'Dán toàn bộ kết quả từ script get_google_sheets_token.py vào ô Access Token rồi nhấn nút "Tự động điền" hoặc nhập từng trường.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isDark, {
    int maxLines = 1,
    bool isSecret = false,
    bool showAutoFill = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isSecret,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(icon, color: AppColors.success, size: 20),
        ),
        suffixIcon: showAutoFill
            ? IconButton(
                icon: Icon(Icons.auto_fix_high_rounded, color: AppColors.info),
                onPressed: _smartPaste,
                tooltip: 'Tự động điền từ nội dung đã dán',
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.success, width: 2),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.heroBlue,
              borderRadius: AppRadius.borderMd,
            ),
            child: ElevatedButton.icon(
              onPressed: _saveToken,
              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 20),
              label: const Text('Lưu cấu hình', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.heroGreen,
              borderRadius: AppRadius.borderMd,
            ),
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncAll,
              icon: _isSyncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
              label: Text(_isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ ngay', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              ),
            ),
          ),
        ),
      ],
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
