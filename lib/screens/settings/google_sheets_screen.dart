import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/google_sheets_service.dart';
import '../../providers/overtime_provider.dart';

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
    final service = GoogleSheetsService();
    await service.setAccessToken(_tokenController.text.trim());
    await service.setRefreshToken(_refreshTokenController.text.trim());
    await service.setClientId(_clientIdController.text.trim());
    await service.setClientSecret(_clientSecretController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu cấu hình Google Sheets!'), backgroundColor: Colors.green));
    }
  }

  void _smartPaste() async {
    // Get text from clipboard
    // For simplicity in this environment, I'll just show a dialog or use a dedicated field
    // But here I'll implement a logic that parses the text if pasted into the Access Token field
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
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tự động điền các trường!'), backgroundColor: Colors.blue));
  }

  Future<void> _syncAll() async {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    setState(() => _status = 'Đang đồng bộ...');
    await provider.syncAllProjectsToSheets();
    if (mounted) {
      setState(() => _status = 'Đã đồng bộ xong');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đồng bộ tất cả dự án lên Google Sheets!'), backgroundColor: Colors.green));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Google Sheets')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cấu hình Google Sheets API', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Dán toàn bộ kết quả từ script get_google_sheets_token.py vào ô Access Token rồi nhấn "Tự động điền" hoặc nhập từng trường.'),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Access Token',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_fix_high),
                  onPressed: _smartPaste,
                  tooltip: 'Tự động điền từ nội dung đã dán',
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refreshTokenController,
              decoration: const InputDecoration(
                labelText: 'Refresh Token (Để tự động gia hạn)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clientSecretController,
              decoration: const InputDecoration(
                labelText: 'Client Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saveToken, 
                    icon: const Icon(Icons.save),
                    label: const Text('Lưu cấu hình'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _syncAll, 
                    icon: const Icon(Icons.sync),
                    label: const Text('Đồng bộ ngay'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_status.isNotEmpty)
              Center(child: Text(_status, style: const TextStyle(fontStyle: FontStyle.italic))),
          ],
        ),
      ),
    );
  }
}


