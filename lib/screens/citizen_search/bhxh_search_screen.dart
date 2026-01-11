import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';

class BhxhSearchScreen extends StatefulWidget {
  final CitizenProfile? profile;
  const BhxhSearchScreen({super.key, this.profile});

  @override
  State<BhxhSearchScreen> createState() => _BhxhSearchScreenState();
}

class _BhxhSearchScreenState extends State<BhxhSearchScreen> {
  final _bhxhController = TextEditingController();
  final _idController = TextEditingController();
  final _captchaController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingCaptcha = true;
  late final WebViewController _headlessController;
  String? _captchaImageUrl;
  String _statusMessage = 'Đang kết nối...';
  bool _showResults = false;
  List<Map<String, String>> _results = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.profile?.bhxhId != null) {
      _bhxhController.text = widget.profile!.bhxhId!;
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
      _statusMessage = 'Đang kết nối BHXH Việt Nam...';
      _errorMessage = null;
    });
    
    _headlessController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('baohiemxahoi.gov.vn')) {
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
      ..loadRequest(Uri.parse('https://baohiemxahoi.gov.vn/tracuu/Pages/tra-cuu-ho-gia-dinh.aspx'));
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      // BHXH captcha logic
      final captchaSrc = await _headlessController.runJavaScriptReturningResult(
        "document.querySelector('img[id*=\"captcha\"], img[src*=\"Captcha\Text\"]')?.src || ''"
      );
      
      final src = captchaSrc.toString().replaceAll('"', '');
      if (mounted) {
        if (src.isNotEmpty && src != 'null') {
          setState(() {
            _captchaImageUrl = src;
            _isLoadingCaptcha = false;
            _statusMessage = 'Sẵn sàng tra cứu';
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Lỗi Captcha: $e');
    }
  }

  Future<void> _performSearch() async {
    if (_bhxhController.text.isEmpty && _idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập Mã BHXH hoặc CCCD')));
      return;
    }
    if (_captchaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập Captcha')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang gửi yêu cầu...';
      _errorMessage = null;
    });

    try {
      // BHXH form handling
      await _headlessController.runJavaScript('''
        (function() {
          const txtBHXH = document.querySelector('input[id*="maSoBHXH"]');
          const txtCCCD = document.querySelector('input[id*="soCMND"]');
          const txtCaptcha = document.querySelector('input[id*="captcha"]');
          if(txtBHXH) txtBHXH.value = '${_bhxhController.text}';
          if(txtCCCD) txtCCCD.value = '${_idController.text}';
          if(txtCaptcha) txtCaptcha.value = '${_captchaController.text}';
          const btn = document.querySelector('button[id*="btnTraCuu"], input[type="submit"]');
          if(btn) btn.click();
        })()
      ''');

      await Future.delayed(const Duration(seconds: 4));

      final result = await _headlessController.runJavaScriptReturningResult('''
        (function() {
          const table = document.querySelector('table.table-result, .table-responsive table');
          if (!table) return JSON.stringify([]);
          const rows = table.querySelectorAll('tr');
          let data = [];
          for(let i = 1; i < rows.length; i++) {
            const cells = rows[i].querySelectorAll('td');
            if(cells.length >= 4) {
              data.push({
                'name': cells[1]?.innerText.trim() || '',
                'bhxh_id': cells[2]?.innerText.trim() || '',
                'gender': cells[3]?.innerText.trim() || '',
                'dob': cells[4]?.innerText.trim() || '',
                'address': cells[5]?.innerText.trim() || ''
              });
            }
          }
          return JSON.stringify(data);
        })()
      ''');

      final resultStr = result.toString();
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"')
          ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"')
          : resultStr;
      
      final List<dynamic> json = jsonDecode(cleanJson);
      
      if (mounted) {
        setState(() {
          _results = json.cast<Map<String, String>>();
          _showResults = true;
          _isLoading = false;
          _statusMessage = _results.isEmpty ? 'Không tìm thấy dữ liệu' : 'Đã lấy dữ liệu thành công';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi: $e';
          _isLoading = false;
        });
        _initHeadlessWebView();
      }
    }
  }

  void _useProfile(CitizenProfile profile) {
    setState(() {
      if (profile.bhxhId != null) _bhxhController.text = profile.bhxhId!;
      if (profile.cccdId != null) _idController.text = profile.cccdId!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra cứu BHXH (Native)'),
        backgroundColor: Colors.green[800],
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
                backgroundColor: Colors.green[800],
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('TRA CỨU BHXH'),
            ),
            if (_showResults) _buildResultsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorMessage != null ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(_errorMessage != null ? Icons.error : Icons.info, color: _errorMessage != null ? Colors.red : Colors.green),
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
          controller: _bhxhController,
          decoration: const InputDecoration(labelText: 'Mã số BHXH', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _idController,
          decoration: const InputDecoration(labelText: 'Số CCCD', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Consumer<OvertimeProvider>(
          builder: (context, provider, _) {
            final profiles = provider.citizenProfiles.where((p) => (p.bhxhId != null && p.bhxhId!.isNotEmpty) || (p.cccdId != null && p.cccdId!.isNotEmpty)).toList();
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

  Widget _buildResultsList() {
    if (_results.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text('Không tìm thấy kết quả'));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        return Card(
          margin: const EdgeInsets.only(top: 10),
          child: ListTile(
            title: Text(r['name'] ?? ''),
            subtitle: Text('BHXH: ${r['bhxh_id']} - Ngày sinh: ${r['dob']}'),
          ),
        );
      },
    );
  }
}
