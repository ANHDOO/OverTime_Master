import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';

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
  Uint8List? _captchaBytes; // Changed from URL to bytes for session consistency
  String _statusMessage = 'Đang khởi tạo...';
  bool _showResults = false;
  List<Map<String, String>> _results = [];
  String? _errorMessage;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _mstController.text = widget.profile!.taxId ?? widget.profile!.cccdId ?? '';
      _idController.text = widget.profile!.cccdId ?? '';
    }
    _initFromService();
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.mst);

    if (service.isReady(LookupType.mst)) {
      // Force a reload to ensure fresh session and valid captcha
      debugPrint('[MST] Controller ready, forcing reload for fresh session');
      _initHeadlessWebView();
    } else {
      _initHeadlessWebView();
    }
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;

    setState(() {
      _isLoadingCaptcha = true;
      _captchaBytes = null;
      _statusMessage = 'Đang kết nối cổng Thuế...';
      _errorMessage = null;
    });

    _headlessController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('gdt.gov.vn')) {
              debugPrint('[MST] Page loaded: $url');
              // Give it a moment to settle session/cookies
              await Future.delayed(const Duration(milliseconds: 800));
              await _extractCaptcha();
            }
          },
          onWebResourceError: (error) {
            debugPrint('[MST] WebResourceError: ${error.description}, type: ${error.errorType}');
            // Ignore some non-fatal errors like ERR_FAILED which often happens for trackers/ads
            if (error.description.contains('ERR_FAILED') || error.description.contains('ERR_CONNECTION_REFUSED')) {
               // If it's the main page failing, we should show error, but often these are subresources
               return;
            }
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
    
    // Clear old captcha input when reloading
    _captchaController.clear();
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      setState(() => _statusMessage = 'Đang lấy mã Captcha...');

      // Chờ captcha tải xong hoàn toàn (thêm thời gian chờ)
      await Future.delayed(const Duration(seconds: 2));
      
      // Kiểm tra captcha đã load chưa bằng polling
      bool captchaReady = false;
      for (int i = 0; i < 10; i++) {
        final checkResult = await _headlessController!.runJavaScriptReturningResult('''
          (function() {
            var img = document.querySelector('img[src*="captcha"]');
            if (!img) return 'NOT_FOUND';
            if (!img.complete) return 'LOADING';
            if (img.naturalWidth === 0) return 'LOADING';
            return 'READY';
          })()
        ''');
        
        final status = checkResult.toString().replaceAll('"', '');
        if (status == 'READY') {
          captchaReady = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (!captchaReady) {
        throw 'Captcha không tải được sau 5 giây';
      }

      // Extract captcha as base64 from WebView canvas (same session)
      final captchaData = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          var img = document.querySelector('img[src*="captcha"]');
          if (!img) return JSON.stringify({src: '', base64: ''});
          if (!img.complete || img.naturalWidth === 0) return JSON.stringify({src: img.src, base64: 'loading'});
          
          var canvas = document.createElement('canvas');
          canvas.width = img.naturalWidth;
          canvas.height = img.naturalHeight;
          var ctx = canvas.getContext('2d');
          ctx.drawImage(img, 0, 0);
          return JSON.stringify({
            src: img.src,
            base64: canvas.toDataURL('image/png').split(',')[1]
          });
        })()
      ''');

      // Handle potential double-encoding or quoting from runJavaScriptReturningResult
      String rawJson = captchaData.toString();
      debugPrint('[MST] Raw captcha data: ${rawJson.substring(0, rawJson.length > 100 ? 100 : rawJson.length)}...');
      
      dynamic decodedData;
      try {
        // Try decoding once
        decodedData = jsonDecode(rawJson);
        // If it's still a string, it was double-encoded
        if (decodedData is String) {
          decodedData = jsonDecode(decodedData);
        }
      } catch (e) {
        debugPrint('[MST] JSON decode error: $e');
        // Fallback: if it's already a string that looks like JSON but failed decode, 
        // it might be because of how toString() handles it.
        if (rawJson.startsWith('{')) {
           decodedData = jsonDecode(rawJson);
        } else {
           throw e;
        }
      }
      
      if (decodedData is! Map) {
        throw 'Decoded data is not a Map: ${decodedData.runtimeType}';
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(decodedData);
      final String src = data['src'] ?? '';
      final String base64Str = data['base64'] ?? '';
      
      debugPrint('[MST] Captcha Src: $src');
      debugPrint('[MST] Captcha base64 length: ${base64Str.length}');

      if (mounted) {
        if (base64Str.isNotEmpty && base64Str.length > 100) {
          final bytes = base64Decode(base64Str);
          setState(() {
            _captchaBytes = bytes;
            _isLoadingCaptcha = false;
            _statusMessage = 'Vui lòng nhập mã xác thực';
          });
        } else {
          _retryCount++;
          if (_retryCount < 3) {
            debugPrint('[MST] Retrying captcha extraction... count: $_retryCount');
            await Future.delayed(const Duration(seconds: 1));
            await _extractCaptcha();
          } else {
            setState(() {
              _errorMessage = 'Không tìm thấy mã xác thực trên trang.';
              _isLoadingCaptcha = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[MST] Extract Captcha Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi xử lý Captcha: $e';
          _isLoadingCaptcha = false;
        });
      }
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
      _statusMessage = 'Đang tra cứu dữ liệu...';
      _errorMessage = null;
      _showResults = false;
    });

    try {
      // 1. First discover all input field names
      final allInputs = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          var inputs = document.querySelectorAll('input');
          var names = [];
          for(var i = 0; i < inputs.length; i++) {
            names.push(inputs[i].name + ':' + inputs[i].type);
          }
          return names.join(', ');
        })()
      ''');
      debugPrint('[MST] All inputs: $allInputs');

      // 2. Fill form - try multiple selector patterns for ID field
      debugPrint('[MST] Filling form: mst=${_mstController.text}, id=${_idController.text}, captcha=${_captchaController.text}');
      
      final fillResult = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          var mstInput = document.querySelector('input[name="mst"]');
          // Try multiple names for CCCD/CMND field
          var idInput = document.querySelector('input[name="idCard"]') 
                     || document.querySelector('input[name="cmt"]')
                     || document.querySelector('input[name="cmnd"]')
                     || document.querySelector('input[name="cmtnd"]')
                     || document.querySelector('input[name="cccd"]')
                     || document.querySelector('input[name="soCMND"]');
          var captchaInput = document.querySelector('input[name="captcha"]');
          
          if(mstInput) mstInput.value = '${_mstController.text}';
          if(idInput) idInput.value = '${_idController.text}';
          if(captchaInput) captchaInput.value = '${_captchaController.text}';
          
          return 'mst:' + (mstInput ? 'found' : 'null') + ',id:' + (idInput ? 'found(' + idInput.name + ')' : 'null') + ',captcha:' + (captchaInput ? 'found' : 'null');
        })()
      ''');
      debugPrint('[MST] Form fields: $fillResult');

      // Submit form
      await _headlessController!.runJavaScript('''
        var form = document.myform || document.forms[0];
        if(form) { 
          console.log('Submitting form');
          form.submit(); 
        }
      ''');

      // 2. Wait for navigation/update - tăng lên 3 giây và kiểm tra kết quả
      await Future.delayed(const Duration(seconds: 3));
      
      // Kiểm tra xem trang đã cập nhật chưa (có kết quả hoặc lỗi)
      for (int i = 0; i < 5; i++) {
        final pageCheck = await _headlessController!.runJavaScriptReturningResult('''
          (function() {
            if (document.body.innerText.includes('Sai mã xác nhận') || document.body.innerText.includes('sai mã xác nhận')) return 'CAPTCHA_ERROR';
            if (document.body.innerText.includes('BẢNG THÔNG TIN')) return 'HAS_DATA';
            if (document.body.innerText.includes('Không tìm thấy')) return 'NO_DATA';
            return 'WAITING';
          })()
        ''');
        
        final status = pageCheck.toString().replaceAll('"', '');
        if (status != 'WAITING') break;
        await Future.delayed(const Duration(seconds: 1));
      }

      // 3. Debug: Check page content after submission
      final debugInfo = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          var tables = document.querySelectorAll('table');
          var info = 'Tables:' + tables.length;
          
          // Check for BẢNG THÔNG TIN TRA CỨU
          info += ', hasBangThongTin:' + document.body.innerText.includes('BẢNG THÔNG TIN');
          info += ', hasNNT:' + document.body.innerText.includes('NNT');
          info += ', has096:' + document.body.innerText.includes('096200009020');
          info += ', hasLYANH:' + document.body.innerText.includes('LÝ ANH');
          
          // Get current URL
          info += ', url:' + window.location.href;
          
          return info;
        })()
      ''');
      debugPrint('[MST] After submit: $debugInfo');

      // 4. Check for error messages
      final errorCheck = await _headlessController!.runJavaScriptReturningResult(
        "document.body.innerText.includes('Sai mã xác nhận') || document.body.innerText.includes('sai mã xác nhận')"
      );

      if (errorCheck.toString() == 'true') {
        if (mounted) {
          setState(() {
            _errorMessage = 'Mã xác thực không chính xác';
            _isLoading = false;
          });
          _retryCount = 0;
          _initHeadlessWebView();
        }
        return;
      }

      // 5. Get body text snippet for debugging
      final bodySnippet = await _headlessController!.runJavaScriptReturningResult(
        "document.body.innerText.substring(0, 500)"
      );
      debugPrint('[MST] Body snippet: $bodySnippet');

      // 6. Scrape results table - more flexible
      final result = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          var tables = document.querySelectorAll('table');
          var data = [];
          console.log('Found ' + tables.length + ' tables');
          
          for(var t = 0; t < tables.length; t++) {
            var rows = tables[t].querySelectorAll('tr');
            console.log('Table ' + t + ' has ' + rows.length + ' rows');
            
            for(var i = 0; i < rows.length; i++) {
              var cells = rows[i].querySelectorAll('td');
              console.log('Row ' + i + ' has ' + cells.length + ' cells');
              
              // Look for row with MST data (at least 4 cells with number in one of them)
              if(cells.length >= 4) {
                for(var c = 0; c < cells.length; c++) {
                  var cellText = cells[c]?.innerText?.trim() || '';
                  // Check if any cell contains a long number (MST or CCCD)
                  if(/^[0-9]{9,}/.test(cellText)) {
                    data.push({
                      'mst': cells[1]?.innerText?.trim() || cells[0]?.innerText?.trim() || '',
                      'name': cells[2]?.innerText?.trim() || cells[1]?.innerText?.trim() || '',
                      'agency': cells[3]?.innerText?.trim() || cells[2]?.innerText?.trim() || '',
                      'status': cells[4]?.innerText?.trim() || cells[3]?.innerText?.trim() || 'Đang hoạt động'
                    });
                    break;
                  }
                }
              }
            }
          }
          return JSON.stringify(data);
        })()
      ''');

      debugPrint('[MST] Scrape Result: $result');

      final resultStr = result.toString();
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"')
          ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"')
          : resultStr;

      final List<dynamic> json = jsonDecode(cleanJson);

      if (mounted) {
        setState(() {
          _results = json.map((e) => Map<String, String>.from(e as Map)).toList();
          _showResults = true;
          _isLoading = false;
          _statusMessage = _results.isEmpty 
              ? 'Không tìm thấy thông tin người nộp thuế' 
              : 'Tìm thấy ${_results.length} kết quả';
        });
      }

    } catch (e) {
      debugPrint('[MST] Search Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi hệ thống: $e';
          _isLoading = false;
        });
        _initHeadlessWebView();
      }
    }
  }

  void _useProfile(CitizenProfile profile) {
    debugPrint('[MST] Using profile: ${profile.label}, taxId: ${profile.taxId}, cccdId: ${profile.cccdId}');
    setState(() {
      // Use taxId if available, otherwise fallback to cccdId for the MST field 
      // as the website allows searching MST by CCCD
      _mstController.text = profile.taxId ?? profile.cccdId ?? '';
      _idController.text = profile.cccdId ?? '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã chọn: ${profile.label}'), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra cứu Mã số thuế'),
        backgroundColor: Colors.red[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(),
            const SizedBox(height: 20),
            _buildInputs(),
            const SizedBox(height: 20),
            _buildCaptchaSection(),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: (_isLoading || _isLoadingCaptcha) ? null : _performSearch,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Đang tra cứu...' : 'TRA CỨU'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
            if (_showResults) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              _buildResultsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _errorMessage != null ? Colors.red[50] : (_showResults ? Colors.green[50] : Colors.red[50]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _errorMessage != null ? Colors.red[200]! : (_showResults ? Colors.green[200]! : Colors.red[200]!)),
      ),
      child: Row(
        children: [
          if (_isLoading || _isLoadingCaptcha)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(
              _errorMessage != null ? Icons.error_outline : (_showResults ? Icons.check_circle : Icons.info_outline),
              color: _errorMessage != null ? Colors.red : (_showResults ? Colors.green : Colors.red[800]),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? _statusMessage,
              style: TextStyle(color: _errorMessage != null ? Colors.red[800] : Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
          if (_errorMessage != null)
            IconButton(onPressed: _initHeadlessWebView, icon: Icon(Icons.refresh, color: Colors.red[800])),
        ],
      ),
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        TextField(
          controller: _mstController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Mã số thuế',
            prefixIcon: const Icon(Icons.numbers),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _idController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Số CCCD/CMND',
            prefixIcon: const Icon(Icons.badge),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Consumer<OvertimeProvider>(
          builder: (context, provider, _) {
            final profiles = provider.citizenProfiles;
            if (profiles.isEmpty) return const SizedBox.shrink();
            return SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final p = profiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text(p.label),
                      onPressed: () => _useProfile(p),
                      backgroundColor: Colors.red[50],
                      labelStyle: TextStyle(color: Colors.red[800], fontSize: 12),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCaptchaSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Xác thực bảo mật', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          if (_isLoadingCaptcha)
            const Center(child: Padding(padding: EdgeInsets.all(10.0), child: CircularProgressIndicator()))
          else if (_captchaBytes != null)
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.memory(
                        _captchaBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        CitizenLookupService().reset(LookupType.mst);
                        _retryCount = 0;
                        _captchaBytes = null;
                        _initFromService();
                      },
                      icon: const Icon(Icons.refresh, size: 28),
                      tooltip: 'Đổi mã khác',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _captchaController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4),
                  decoration: InputDecoration(
                    hintText: 'Nhập mã xác thực',
                    hintStyle: const TextStyle(fontSize: 16, letterSpacing: 0, fontWeight: FontWeight.normal),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.red[50]?.withOpacity(0.3),
                  ),
                ),
              ],
            )
          else
            const Center(child: Text('Lỗi tải Captcha', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.orange[600]),
            const SizedBox(height: 12),
            const Text('KHÔNG TÌM THẤY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 4),
            const Text('Không tìm thấy thông tin người nộp thuế với dữ liệu đã nhập.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('KẾT QUẢ TRA CỨU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
              child: Text('${_results.length} kết quả', style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final r = _results[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red[800])),
                    const SizedBox(height: 8),
                    _detailRow(Icons.numbers, 'MST', r['mst']),
                    _detailRow(Icons.business, 'Cơ quan thuế', r['agency']),
                    _detailRow(Icons.check_circle, 'Trạng thái', r['status']),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
