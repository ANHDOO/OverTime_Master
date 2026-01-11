import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/citizen_profile.dart';

class TrafficFineSearchScreen extends StatefulWidget {
  final CitizenProfile? profile;
  const TrafficFineSearchScreen({super.key, this.profile});

  @override
  State<TrafficFineSearchScreen> createState() => _TrafficFineSearchScreenState();
}

class _TrafficFineSearchScreenState extends State<TrafficFineSearchScreen> {
  final _plateController = TextEditingController();
  final _captchaController = TextEditingController();
  String _vehicleType = '1'; // 1: Car, 2: Motorcycle, 3: Electric
  bool _isLoading = false;
  late final WebViewController _headlessController;
  String? _captchaImageUrl;
  bool _showResults = false;
  List<Map<String, String>> _violations = [];

  @override
  void initState() {
    super.initState();
    if (widget.profile?.licensePlate != null) {
      _plateController.text = widget.profile!.licensePlate!;
    }
    _initHeadlessWebView();
  }

  void _initHeadlessWebView() {
    _headlessController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('csgt.vn')) {
              _extractCaptcha();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.csgt.vn/tra-cuu-phat-nguoi-43.html'));
  }

  Future<void> _extractCaptcha() async {
    // Inject JS to find the captcha image src
    final captchaSrc = await _headlessController.runJavaScriptReturningResult(
      "document.querySelector('img[src*=\"captcha\"]').src"
    ) as String;
    setState(() {
      _captchaImageUrl = captchaSrc.replaceAll('"', '');
    });
  }

  Future<void> _performSearch() async {
    if (_plateController.text.isEmpty || _captchaController.text.isEmpty) return;

    setState(() => _isLoading = true);

    // 1. Fill form via JS
    await _headlessController.runJavaScript('''
      document.getElementsByName('bienso')[0].value = '${_plateController.text}';
      document.getElementsByName('loaxe')[0].value = '$_vehicleType';
      document.getElementsByName('captcha')[0].value = '${_captchaController.text}';
      document.querySelector('button[type="submit"]').click();
    ''');

    // 2. Wait and Scrape results
    await Future.delayed(const Duration(seconds: 2));
    final result = await _headlessController.runJavaScriptReturningResult('''
      (function() {
        const rows = document.querySelectorAll('.table-responsive table tr');
        let data = [];
        for(let i = 1; i < rows.length; i++) {
          const cells = rows[i].querySelectorAll('td');
          if(cells.length > 5) {
            data.push({
              'time': cells[1].innerText,
              'location': cells[2].innerText,
              'violation': cells[3].innerText,
              'status': cells[4].innerText,
              'unit': cells[5].innerText
            });
          }
        }
        return JSON.stringify(data);
      })()
    ''') as String;

    final List<dynamic> json = jsonDecode(result.replaceAll('"', ''));
    setState(() {
      _violations = json.cast<Map<String, String>>();
      _showResults = true;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kiểm tra Phạt nguội')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _plateController,
              decoration: const InputDecoration(labelText: 'Biển số xe', hintText: 'VD: 30A12345'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              items: const [
                DropdownMenuItem(value: '1', child: Text('Ô tô')),
                DropdownMenuItem(value: '2', child: Text('Mô tô')),
                DropdownMenuItem(value: '3', child: Text('Xe điện')),
              ],
              onChanged: (v) => setState(() => _vehicleType = v!),
              decoration: const InputDecoration(labelText: 'Loại phương tiện'),
            ),
            const SizedBox(height: 16),
            if (_captchaImageUrl != null)
              Row(
                children: [
                   Image.network(_captchaImageUrl!, height: 50),
                   const SizedBox(width: 12),
                   Expanded(
                     child: TextField(
                       controller: _captchaController,
                       decoration: const InputDecoration(labelText: 'Nhập mã captcha'),
                     ),
                   ),
                   IconButton(onPressed: _initHeadlessWebView, icon: const Icon(Icons.refresh)),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _performSearch,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Tra cứu Ngay'),
            ),
            if (_showResults) _buildResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_violations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 30),
        child: Text('Chúc mừng! Không tìm thấy lỗi vi phạm.'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _violations.length,
      itemBuilder: (context, index) {
        final v = _violations[index];
        return Card(
          child: ListTile(
            title: Text(v['violation'] ?? ''),
            subtitle: Text('${v['time']} - ${v['status']}'),
          ),
        );
      },
    );
  }
}
