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
  String _vehicleType = '1';
  bool _isLoading = false;
  bool _isLoadingCaptcha = true;
  late WebViewController _headlessController;
  String? _captchaImageUrl;
  String _statusMessage = 'Đang kết nối đến CSGT...';
  bool _showResults = false;
  List<Map<String, dynamic>> _violations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.profile?.licensePlate != null) {
      _plateController.text = widget.profile!.licensePlate!;
    }
    _initHeadlessWebView();
  }

  void _initHeadlessWebView() {
    setState(() {
      _isLoadingCaptcha = true;
      _captchaImageUrl = null;
      _statusMessage = 'Đang kết nối đến CSGT...';
      _errorMessage = null;
    });
    
    _headlessController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            debugPrint('[TrafficFine] Page finished: $url');
            if (url.contains('csgt.vn')) {
              await _extractCaptcha();
            }
          },
          onWebResourceError: (error) {
            debugPrint('[TrafficFine] WebView Error: ${error.description}');
            setState(() {
              _errorMessage = 'Lỗi kết nối: ${error.description}';
              _isLoadingCaptcha = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.csgt.vn/tra-cuu-phat-nguoi-43.html'));
  }

  Future<void> _extractCaptcha() async {
    try {
      setState(() => _statusMessage = 'Đang lấy mã Captcha...');
      
      // Wait a bit for page to fully render
      await Future.delayed(const Duration(milliseconds: 500));
      
      final captchaSrc = await _headlessController.runJavaScriptReturningResult(
        "document.querySelector('img[src*=\"captcha\"]')?.src || ''"
      );
      
      final src = captchaSrc.toString().replaceAll('"', '');
      debugPrint('[TrafficFine] Captcha URL: $src');
      
      if (src.isNotEmpty && src != 'null') {
        setState(() {
          _captchaImageUrl = src;
          _isLoadingCaptcha = false;
          _statusMessage = 'Sẵn sàng tra cứu';
        });
      } else {
        setState(() {
          _errorMessage = 'Không thể lấy mã Captcha. Vui lòng thử lại.';
          _isLoadingCaptcha = false;
        });
      }
    } catch (e) {
      debugPrint('[TrafficFine] Extract Captcha Error: $e');
      setState(() {
        _errorMessage = 'Lỗi: $e';
        _isLoadingCaptcha = false;
      });
    }
  }

  Future<void> _performSearch() async {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập biển số xe')),
      );
      return;
    }
    if (_captchaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã Captcha')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tra cứu...';
      _errorMessage = null;
      _showResults = false;
    });

    try {
      // Fill form via JS
      await _headlessController.runJavaScript('''
        document.getElementsByName('bienso')[0].value = '${_plateController.text}';
        document.getElementsByName('loaixe')[0].value = '$_vehicleType';
        document.getElementsByName('captcha')[0].value = '${_captchaController.text}';
        document.querySelector('button[type="submit"]').click();
      ''');

      // Wait for page to load results
      await Future.delayed(const Duration(seconds: 3));

      // Check for errors first
      final errorCheck = await _headlessController.runJavaScriptReturningResult(
        "document.querySelector('.alert-danger')?.innerText || ''"
      );
      final errorText = errorCheck.toString().replaceAll('"', '');
      
      if (errorText.isNotEmpty) {
        setState(() {
          _errorMessage = errorText;
          _isLoading = false;
          _statusMessage = 'Tra cứu thất bại';
        });
        // Refresh captcha after error
        _initHeadlessWebView();
        return;
      }

      // Scrape results
      final result = await _headlessController.runJavaScriptReturningResult('''
        (function() {
          const rows = document.querySelectorAll('.table-responsive table tbody tr');
          let data = [];
          for(let i = 0; i < rows.length; i++) {
            const cells = rows[i].querySelectorAll('td');
            if(cells.length >= 5) {
              data.push({
                'stt': cells[0]?.innerText || '',
                'time': cells[1]?.innerText || '',
                'location': cells[2]?.innerText || '',
                'violation': cells[3]?.innerText || '',
                'status': cells[4]?.innerText || '',
                'unit': cells[5]?.innerText || ''
              });
            }
          }
          return JSON.stringify(data);
        })()
      ''');

      debugPrint('[TrafficFine] Result: $result');
      
      final resultStr = result.toString();
      // Handle escaped JSON from WebView
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"')
          ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"')
          : resultStr;
      
      final List<dynamic> json = jsonDecode(cleanJson);
      
      setState(() {
        _violations = json.cast<Map<String, dynamic>>();
        _showResults = true;
        _isLoading = false;
        _statusMessage = _violations.isEmpty 
            ? 'Không tìm thấy vi phạm!' 
            : 'Tìm thấy ${_violations.length} vi phạm';
      });
      
    } catch (e) {
      debugPrint('[TrafficFine] Search Error: $e');
      setState(() {
        _errorMessage = 'Lỗi tra cứu: $e';
        _isLoading = false;
        _statusMessage = 'Tra cứu thất bại';
      });
      // Refresh captcha after error
      _initHeadlessWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra Phạt nguội'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _errorMessage != null 
                    ? Colors.red[50] 
                    : (_showResults ? Colors.green[50] : Colors.blue[50]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _errorMessage != null 
                      ? Colors.red[200]! 
                      : (_showResults ? Colors.green[200]! : Colors.blue[200]!),
                ),
              ),
              child: Row(
                children: [
                  if (_isLoading || _isLoadingCaptcha)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      _errorMessage != null 
                          ? Icons.error_outline 
                          : (_showResults ? Icons.check_circle : Icons.info_outline),
                      color: _errorMessage != null 
                          ? Colors.red 
                          : (_showResults ? Colors.green : Colors.blue),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage ?? _statusMessage,
                      style: TextStyle(
                        color: _errorMessage != null ? Colors.red[800] : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Input Form
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Biển số xe',
                hintText: 'VD: 30A12345',
                prefixIcon: const Icon(Icons.directions_car),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
              decoration: InputDecoration(
                labelText: 'Loại phương tiện',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Captcha Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mã xác thực', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_isLoadingCaptcha)
                    const Center(child: CircularProgressIndicator())
                  else if (_captchaImageUrl != null)
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _captchaImageUrl!,
                              height: 50,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _captchaController,
                            decoration: InputDecoration(
                              labelText: 'Nhập mã',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _initHeadlessWebView,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Lấy mã mới',
                        ),
                      ],
                    )
                  else
                    Center(
                      child: TextButton.icon(
                        onPressed: _initHeadlessWebView,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Search Button
            ElevatedButton.icon(
              onPressed: (_isLoading || _isLoadingCaptcha) ? null : _performSearch,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Đang tra cứu...' : 'Tra cứu Ngay'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            
            // Results Section
            if (_showResults) ...[
              const SizedBox(height: 24),
              _buildResultsList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green[600]),
            const SizedBox(height: 12),
            const Text(
              'Chúc mừng!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('Không tìm thấy lỗi vi phạm nào.'),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kết quả: ${_violations.length} vi phạm',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _violations.length,
          itemBuilder: (context, index) {
            final v = _violations[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v['violation']?.toString() ?? 'Không rõ lỗi',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(v['time']?.toString() ?? '', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            v['location']?.toString() ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        v['status']?.toString() ?? '',
                        style: TextStyle(color: Colors.orange[800], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
