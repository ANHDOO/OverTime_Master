import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';
import '../../services/captcha_service.dart';

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
  bool _isLoadingCaptcha = false;
  WebViewController? _headlessController;
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
    _initFromService();
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.bhxh);
    
    // Check for background-solved captcha
    final preSolved = service.getSolvedCaptcha(LookupType.bhxh);
    if (preSolved != null && preSolved.isNotEmpty) {
      setState(() {
        _captchaController.text = preSolved;
        _isLoadingCaptcha = false;
        _statusMessage = 'Sẵn sàng tra cứu (Captcha đã giải ngầm)';
      });
      _tryAutoSubmit();
    } else if (service.isReady(LookupType.bhxh)) {
      _extractCaptcha();
    } else {
      _initHeadlessWebView();
    }
  }

  void _tryAutoSubmit() {
    if (widget.profile != null && (_bhxhController.text.isNotEmpty || _idController.text.isNotEmpty) && _captchaController.text.isNotEmpty) {
      if (!_showResults && !_isLoading) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && !_isLoading) _performSearch();
        });
      }
    }
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;
    setState(() {
      _isLoadingCaptcha = true;
      _captchaImageUrl = null;
      _statusMessage = 'Đang kết nối cổng BHXH...';
      _errorMessage = null;
    });
    
    _headlessController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('baohiemxahoi.gov.vn')) {
              await Future.delayed(const Duration(milliseconds: 500));
              await _extractCaptcha();
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Lỗi kết nối: ${error.description}';
                _isLoadingCaptcha = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://baohiemxahoi.gov.vn/tracuu/Pages/tra-cuu-ho-gia-dinh.aspx'));
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      // Many gov portals use 'imgCaptcha' or similar
      final captchaSrc = await _headlessController!.runJavaScriptReturningResult(
        "document.querySelector('img[id*=\"captcha\"], img[src*=\"Captcha\"], #imgCaptcha')?.src || ''"
      );
      
      final src = captchaSrc.toString().replaceAll('"', '');
      if (mounted) {
        if (src.isNotEmpty && src != 'null' && src.contains('http')) {
          setState(() {
            _captchaImageUrl = src;
            _isLoadingCaptcha = false;
            _statusMessage = 'Vui lòng nhập Captcha';
          });

          // Attempt auto-solve
          final solved = await CaptchaService().solveCaptchaFromWebView(_headlessController!);
          if (solved != null && solved.isNotEmpty && mounted) {
            setState(() {
              _captchaController.text = solved;
              _statusMessage = 'Mã xác thực đã được tự động điền';
            });
            _tryAutoSubmit();
          }
        } else {
          // If no captcha found, maybe it's not required or invisible
          setState(() {
            _isLoadingCaptcha = false;
            _statusMessage = 'Sẵn sàng tra cứu (Không yêu cầu Captcha)';
          });
          _tryAutoSubmit();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Lỗi kiểm tra Captcha: $e');
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
      await _headlessController!.runJavaScript('''
        (function() {
          function setVal(selector, val) {
            const el = document.querySelector(selector);
            if (el) {
              el.value = val;
              el.dispatchEvent(new Event('input', { bubbles: true }));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            }
          }
          // Selectors for tra-cuu-ho-gia-dinh.aspx
          setVal('#HoTen', '${widget.profile?.label ?? ""}');
          setVal('#CMND', '${_idController.text}');
          setVal('input[id*="captcha"], #captcha', '${_captchaController.text}');
          
          const btn = document.querySelector('#btn-submit, button[type="submit"], .btn-search');
          if(btn) btn.click();
        })()
      ''');

      await Future.delayed(const Duration(seconds: 4));

      final result = await _headlessController!.runJavaScriptReturningResult('''
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
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('TRA CỨU NGAY'),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_captchaImageUrl != null)
                Container(
                  height: 45,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                  child: Image.network(_captchaImageUrl!, fit: BoxFit.contain),
                ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  CitizenLookupService().reset(LookupType.bhxh);
                  _initFromService();
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captchaController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3),
            decoration: InputDecoration(
              hintText: 'Nhập mã Captcha',
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: 0, fontWeight: FontWeight.normal),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.green[50]?.withOpacity(0.3),
            ),
          ),
        ],
      ),
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
