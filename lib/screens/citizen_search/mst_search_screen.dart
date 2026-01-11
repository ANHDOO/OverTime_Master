import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';

class MstSearchScreen extends StatefulWidget {
  final CitizenProfile? profile;
  const MstSearchScreen({super.key, this.profile});

  @override
  State<MstSearchScreen> createState() => _MstSearchScreenState();
}

class _MstSearchScreenState extends State<MstSearchScreen> {
  final _mstController = TextEditingController();
  final _idController = TextEditingController();
  final _captchaController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingCaptcha = true;
  late final WebViewController _headlessController;
  String? _captchaImageUrl;
  String _statusMessage = 'Đang kết nối...';
  bool _showResults = false;
  Map<String, String>? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.profile?.taxId != null) {
      _mstController.text = widget.profile!.taxId!;
    }
    if (widget.profile?.cccdId != null) {
      _idController.text = widget.profile!.cccdId!;
    }
    _initHeadlessWebView();
  }

  void _initHeadlessWebView() {
    setState(() {
      _isLoadingCaptcha = true;
      _captchaImageUrl = null;
      _statusMessage = 'Đang kết nối Tổng cục Thuế...';
      _errorMessage = null;
    });
    
    _headlessController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('tracuunnt.gdt.gov.vn')) {
              await _extractCaptcha();
            }
          },
          onWebResourceError: (error) {
            setState(() {
              _errorMessage = 'Lỗi kết nối: ${error.description}';
              _isLoadingCaptcha = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://tracuunnt.gdt.gov.vn/tcnnt/mstcn.jsp'));
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      // The captcha image has an id or is the only img in a specific div
      final captchaSrc = await _headlessController.runJavaScriptReturningResult(
        "document.querySelector('img[src*=\"captcha\"]')?.src || ''"
      );
      
      final src = captchaSrc.toString().replaceAll('"', '');
      if (mounted) {
        if (src.isNotEmpty && src != 'null') {
          setState(() {
            _captchaImageUrl = src;
            _isLoadingCaptcha = false;
            _statusMessage = 'Vui lòng nhập Captcha';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Lỗi Captcha: $e');
    }
  }

  Future<void> _performSearch() async {
    if (_mstController.text.isEmpty && _idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập MST hoặc Số CCCD')));
      return;
    }
    if (_captchaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập mã Captcha')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tra cứu...';
      _errorMessage = null;
    });

    try {
      await _headlessController.runJavaScript('''
        document.getElementById('mst').value = '${_mstController.text}';
        document.getElementById('id_so_chung_minh').value = '${_idController.text}';
        document.getElementById('captcha').value = '${_captchaController.text}';
        document.querySelector('input[type="submit"], button[type="submit"], .btn_search').click();
      ''');

      await Future.delayed(const Duration(seconds: 3));

      // Scrape results - GDT results are usually in a table with class 'ta_border'
      final result = await _headlessController.runJavaScriptReturningResult('''
        (function() {
          const table = document.querySelector('.ta_border');
          if (!table) return JSON.stringify({error: 'Không tìm thấy kết quả hoặc sai Captcha'});
          const rows = table.querySelectorAll('tr');
          if (rows.length < 2) return JSON.stringify({error: 'Không có dữ liệu'});
          
          const cells = rows[1].querySelectorAll('td');
          return JSON.stringify({
            'mst': cells[1]?.innerText.trim() || '',
            'name': cells[2]?.innerText.trim() || '',
            'agency': cells[3]?.innerText.trim() || '',
            'id_card': cells[4]?.innerText.trim() || '',
            'last_update': cells[5]?.innerText.trim() || '',
            'status': cells[6]?.innerText.trim() || ''
          });
        })()
      ''');

      final resultStr = result.toString();
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"')
          ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"')
          : resultStr;
      
      final data = jsonDecode(cleanJson);
      if (mounted) {
        if (data['error'] != null) {
          setState(() {
            _errorMessage = data['error'];
            _isLoading = false;
          });
          _initHeadlessWebView();
        } else {
          setState(() {
            _result = Map<String, String>.from(data);
            _showResults = true;
            _isLoading = false;
            _statusMessage = 'Đã tìm thấy thông tin';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi tra cứu: $e';
          _isLoading = false;
        });
        _initHeadlessWebView();
      }
    }
  }

  void _useProfile(CitizenProfile profile) {
    setState(() {
      if (profile.taxId != null) _mstController.text = profile.taxId!;
      if (profile.cccdId != null) _idController.text = profile.cccdId!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra cứu Mã số thuế (Native)'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 20),
            _buildInputs(),
            const SizedBox(height: 20),
            _buildCaptcha(),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: (_isLoading || _isLoadingCaptcha) ? null : _performSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('TRA CỨU'),
            ),
            if (_showResults) _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorMessage != null ? Colors.red[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_errorMessage != null ? Icons.error : Icons.info, color: _errorMessage != null ? Colors.red : Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text(_errorMessage ?? _statusMessage)),
        ],
      ),
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        TextField(
          controller: _mstController,
          decoration: const InputDecoration(labelText: 'Mã số thuế', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _idController,
          decoration: const InputDecoration(labelText: 'Số CCCD/CMND', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Consumer<OvertimeProvider>(
          builder: (context, provider, _) {
            final profiles = provider.citizenProfiles.where((p) => (p.taxId != null && p.taxId!.isNotEmpty) || (p.cccdId != null && p.cccdId!.isNotEmpty)).toList();
            return SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: profiles.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(label: Text(profiles[index].label), onPressed: () => _useProfile(profiles[index])),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCaptcha() {
    if (_isLoadingCaptcha) return const CircularProgressIndicator();
    return Row(
      children: [
        if (_captchaImageUrl != null) Image.network(_captchaImageUrl!, height: 40),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _captchaController, decoration: const InputDecoration(labelText: 'Captcha'))),
        IconButton(onPressed: _initHeadlessWebView, icon: const Icon(Icons.refresh)),
      ],
    );
  }

  Widget _buildResults() {
    if (_result == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _resultRow('Người nộp thuế', _result!['name']),
            _resultRow('Mã số thuế', _result!['mst']),
            _resultRow('Cơ quan thuế', _result!['agency']),
            _resultRow('Số CCCD', _result!['id_card']),
            _resultRow('Ngày cập nhật', _result!['last_update']),
            _resultRow('Trạng thái', _result!['status']),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), Text(value ?? '')],
      ),
    );
  }
}
