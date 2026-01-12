import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';
import '../../services/captcha_service.dart';

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
  bool _isLoadingCaptcha = false;
  WebViewController? _headlessController;
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
    _initFromService();
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.mst);
    
    // Check for background-solved captcha
    final preSolved = service.getSolvedCaptcha(LookupType.mst);
    if (preSolved != null && preSolved.isNotEmpty) {
      setState(() {
        _captchaController.text = preSolved;
        _isLoadingCaptcha = false;
        _statusMessage = 'Sẵn sàng tra cứu (Captcha đã giải ngầm)';
      });
      _tryAutoSubmit();
    } else if (service.isReady(LookupType.mst)) {
      _extractCaptcha();
    } else {
      _initHeadlessWebView();
    }
  }

  void _tryAutoSubmit() {
    if (widget.profile != null && (_mstController.text.isNotEmpty || _idController.text.isNotEmpty) && _captchaController.text.isNotEmpty) {
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
      _statusMessage = 'Đang kết nối Tổng cục Thuế...';
      _errorMessage = null;
    });
    
    _headlessController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('tracuunnt.gdt.gov.vn')) {
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
      ..loadRequest(Uri.parse('https://tracuunnt.gdt.gov.vn/tcnnt/mstcn.jsp'));
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      // The captcha image has an id or is the only img in a specific div
      final captchaSrc = await _headlessController!.runJavaScriptReturningResult(
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
          
          // Attempt auto-solve
          final solved = await CaptchaService().solveCaptchaFromWebView(_headlessController!);
          if (solved != null && solved.isNotEmpty && mounted) {
            setState(() {
              _captchaController.text = solved;
              _statusMessage = 'Mã xác thực đã được tự động điền';
            });
            _tryAutoSubmit();
          }
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
      await _headlessController!.runJavaScript('''
        (function() {
          function setInputValueBySelector(selector, val) {
            const el = document.querySelector(selector);
            if (el) {
              el.value = val;
              el.dispatchEvent(new Event('input', { bubbles: true }));
              el.dispatchEvent(new Event('change', { bubbles: true }));
            }
          }
          
          // Ensure we are on the TNCN tab if possible
          const tncnTab = document.querySelector('a[href*="mstcn.jsp"]');
          if (tncnTab && !window.location.href.includes('mstcn.jsp')) {
             tncnTab.click();
             return;
          }

          setInputValueBySelector('input[name="mst"]', '${_mstController.text}');
          // CCCD/CMND field is named 'cmt' and often hidden
          setInputValueBySelector('input[name="cmt"]', '${_idController.text}');
          setInputValueBySelector('#captcha', '${_captchaController.text}');
          
          const btn = document.querySelector('input[type="submit"], .subBtn');
          if (btn) btn.click();
        })()
      ''');

      await Future.delayed(const Duration(seconds: 3));

      // Scrape results - GDT results are usually in a table with class 'ta_border'
      // We also check for error messages like "Sai mã xác nhận"
      final result = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          // Check for error messages first
          const errorMsg = document.querySelector('.error, .alert-danger, .error_text, .notification, .message')?.innerText || '';
          if (errorMsg.includes('mã xác nhận') || errorMsg.includes('captcha') || errorMsg.includes('xác thực')) {
            return JSON.stringify({error: 'Mã xác nhận không chính xác'});
          }
          if (errorMsg.includes('không tìm thấy') || errorMsg.includes('not found')) {
            return JSON.stringify({error: 'Không tìm thấy thông tin người nộp thuế'});
          }
          if (errorMsg.isNotEmpty && errorMsg.length > 0 && errorMsg.length < 200) {
            return JSON.stringify({error: errorMsg.trim()});
          }

          // Look for result table
          const table = document.querySelector('.ta_border, table[width="100%"], table[border="1"], .result-table, #resultTable');
          if (!table) {
             const bodyText = document.body.innerText;
             if (bodyText.includes('không tìm thấy') || bodyText.includes('not found')) {
               return JSON.stringify({error: 'Không tìm thấy thông tin người nộp thuế'});
             }
             return JSON.stringify({error: 'Không tìm thấy bảng kết quả. Có thể do lỗi mạng hoặc sai Captcha.'});
          }

          const rows = table.querySelectorAll('tr');
          if (rows.length < 2) return JSON.stringify({error: 'Không tìm thấy dữ liệu kết quả.'});

          // Find the data row (skip header)
          let dataRow = null;
          for (let i = 1; i < rows.length; i++) {
             const cells = rows[i].querySelectorAll('td');
             // Look for row with substantial data (at least 4 cells)
             if (cells.length >= 4 && cells[0]?.innerText?.trim()) {
                dataRow = cells;
                break;
             }
          }

          if (!dataRow || dataRow.length < 4) return JSON.stringify({error: 'Không tìm thấy dữ liệu hợp lệ.'});

          return JSON.stringify({
            'mst': dataRow[0]?.innerText.trim() || dataRow[1]?.innerText.trim() || '',
            'name': dataRow[1]?.innerText.trim() || dataRow[2]?.innerText.trim() || '',
            'agency': dataRow[2]?.innerText.trim() || dataRow[3]?.innerText.trim() || '',
            'id_card': dataRow[3]?.innerText.trim() || dataRow[4]?.innerText.trim() || '',
            'last_update': dataRow[4]?.innerText.trim() || dataRow[5]?.innerText.trim() || '',
            'status': dataRow[5]?.innerText.trim() || dataRow[6]?.innerText.trim() || ''
          });
        })()
      ''');

      debugPrint('[MST] Scrape Result: $result');

      final resultStr = result.toString();
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"')
          ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"')
          : resultStr;
      
      final data = jsonDecode(cleanJson);
      if (mounted) {
        if (data is Map && data['error'] != null) {
          setState(() {
            _errorMessage = data['error'];
            _isLoading = false;
          });
          _initFromService(); // Refresh captcha
        } else if (data is Map) {
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
                  height: 50,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                  child: Image.network(_captchaImageUrl!, fit: BoxFit.contain),
                ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  CitizenLookupService().reset(LookupType.mst);
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
              hintText: 'Nhập mã xác thực',
              hintStyle: const TextStyle(fontSize: 14, letterSpacing: 0, fontWeight: FontWeight.normal),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.red[50]?.withOpacity(0.3),
            ),
          ),
        ],
      ),
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
