import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';
import '../../services/captcha_service.dart';

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
  bool _isLoadingCaptcha = false;
  WebViewController? _headlessController;
  String? _captchaImageUrl;
  String _statusMessage = 'Đang khởi tạo...';
  bool _showResults = false;
  List<Map<String, dynamic>> _violations = [];
  String? _errorMessage;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.profile?.licensePlate != null) {
      _plateController.text = widget.profile!.licensePlate!;
    }
    _initFromService();
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.phatNguoi);
    
    // Check for background-solved captcha
    final preSolved = service.getSolvedCaptcha(LookupType.phatNguoi);
    if (preSolved != null && preSolved.isNotEmpty) {
      setState(() {
        _captchaController.text = preSolved;
        _isLoadingCaptcha = false;
        _statusMessage = 'Sẵn sàng tra cứu (Captcha đã giải ngầm)';
      });
      _tryAutoSubmit();
    } else if (service.isReady(LookupType.phatNguoi)) {
      _extractCaptcha();
    } else {
      _initHeadlessWebView();
    }
  }

  void _tryAutoSubmit() {
    if (widget.profile != null && _plateController.text.isNotEmpty && _captchaController.text.isNotEmpty) {
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
      _statusMessage = 'Đang kết nối đến CSGT...';
      _errorMessage = null;
    });

    _headlessController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('csgt.vn')) {
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
      ..loadRequest(Uri.parse('https://www.csgt.vn/tra-cuu-phat-nguoi-43.html'));
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      setState(() => _statusMessage = 'Đang lấy mã Captcha...');
      
      // Wait for page to fully render elements
      await Future.delayed(const Duration(seconds: 1));
      
      final captchaSrc = await _headlessController!.runJavaScriptReturningResult(
        "document.querySelector('img[src*=\"captcha\"]')?.src || ''"
      );
      
      final src = captchaSrc.toString().replaceAll('"', '');
      debugPrint('[TrafficFine] Captcha URL: $src');
      
      if (mounted) {
        if (src.isNotEmpty && src != 'null' && src.startsWith('http')) {
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
          _retryCount++;
          if (_retryCount < 3) {
            debugPrint('[TrafficFine] Retrying captcha extraction... count: $_retryCount');
            await Future.delayed(const Duration(seconds: 1));
            await _extractCaptcha();
          } else {
            setState(() {
              _errorMessage = 'Không tìm thấy mã xác thực trên trang web CSGT.';
              _isLoadingCaptcha = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[TrafficFine] Extract Captcha Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi xử lý Captcha: $e';
          _isLoadingCaptcha = false;
        });
      }
    }
  }

  Future<void> _performSearch() async {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập biển số xe')));
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
      // 1. Fill form and submit
      await _headlessController!.runJavaScript('''
        document.getElementsByName('bienso')[0].value = '${_plateController.text}';
        document.getElementsByName('loaxe')[0].value = '$_vehicleType';
        document.getElementsByName('captcha')[0].value = '${_captchaController.text}';
        document.querySelector('button[type="submit"]').click();
      ''');

      // 2. Wait for navigation/update
      await Future.delayed(const Duration(seconds: 3));

      // 3. Check for alerts (errors from server)
      final errorCheck = await _headlessController!.runJavaScriptReturningResult(
        "document.querySelector('.alert-danger')?.innerText || ''"
      );
      final errorText = errorCheck.toString().replaceAll('"', '').trim();
      
      if (mounted && errorText.isNotEmpty) {
        setState(() {
          _errorMessage = 'Trang web báo lỗi: $errorText';
          _isLoading = false;
          _statusMessage = 'Thất bại';
        });
        _initHeadlessWebView(); // Refresh captcha
        return;
      }

      // 4. Scrape results
      final result = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          const rows = document.querySelectorAll('.table-responsive table tbody tr');
          let data = [];
          for(let i = 0; i < rows.length; i++) {
            const cells = rows[i].querySelectorAll('td');
            if(cells.length >= 5) {
              data.push({
                'stt': cells[0]?.innerText.trim() || '',
                'time': cells[1]?.innerText.trim() || '',
                'location': cells[2]?.innerText.trim() || '',
                'violation': cells[3]?.innerText.trim() || '',
                'status': cells[4]?.innerText.trim() || '',
                'unit': cells[5]?.innerText.trim() || ''
              });
            }
          }
          return JSON.stringify(data);
        })()
      ''');

      debugPrint('[TrafficFine] Scrape Result: $result');
      
      final resultStr = result.toString();
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"')
          ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"')
          : resultStr;
      
      final List<dynamic> json = jsonDecode(cleanJson);
      
      if (mounted) {
        setState(() {
          _violations = json.cast<Map<String, dynamic>>();
          _showResults = true;
          _isLoading = false;
          _statusMessage = _violations.isEmpty 
              ? 'Chúc mừng! Bạn không có vi phạm nào.' 
              : 'Tìm thấy ${_violations.length} bản ghi vi phạm';
        });
      }
      
    } catch (e) {
      debugPrint('[TrafficFine] Search Error: $e');
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
    if (profile.licensePlate != null) {
      setState(() {
        _plateController.text = profile.licensePlate!;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chọn biển số: ${profile.licensePlate}'), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiểm tra Phạt nguội (Native)'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            _buildStatusHeader(),
            
            const SizedBox(height: 20),
            
            // Plate Input with Suggestions
            _buildPlateInput(),
            
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _vehicleType,
              items: const [
                DropdownMenuItem(value: '1', child: Row(children: [Icon(Icons.directions_car, size: 20), SizedBox(width: 8), Text('Ô tô')])),
                DropdownMenuItem(value: '2', child: Row(children: [Icon(Icons.motorcycle, size: 20), SizedBox(width: 8), Text('Mô tô / Xe máy')])),
                DropdownMenuItem(value: '3', child: Row(children: [Icon(Icons.electric_bike, size: 20), SizedBox(width: 8), Text('Xe máy điện')])),
              ],
              onChanged: (v) => setState(() => _vehicleType = v!),
              decoration: InputDecoration(
                labelText: 'Loại phương tiện',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Captcha Section
            _buildCaptchaSection(),
            
            const SizedBox(height: 30),
            
            // Action Button
            ElevatedButton.icon(
              onPressed: (_isLoading || _isLoadingCaptcha) ? null : _performSearch,
              icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Đang kiểm tra...' : 'TRA CỨU NGAY'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue[800],
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
        color: _errorMessage != null ? Colors.red[50] : (_showResults ? Colors.green[50] : Colors.blue[50]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _errorMessage != null ? Colors.red[200]! : (_showResults ? Colors.green[200]! : Colors.blue[200]!)),
      ),
      child: Row(
        children: [
          if (_isLoading || _isLoadingCaptcha)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(
              _errorMessage != null ? Icons.error_outline : (_showResults ? Icons.check_circle : Icons.info_outline),
              color: _errorMessage != null ? Colors.red : (_showResults ? Colors.green : Colors.blue),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? _statusMessage,
              style: TextStyle(color: _errorMessage != null ? Colors.red[800] : Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
          if (_errorMessage != null)
            IconButton(onPressed: _initHeadlessWebView, icon: const Icon(Icons.refresh, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildPlateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Biển số xe',
            hintText: 'VD: 30A12345 (Viết liền)',
            prefixIcon: const Icon(Icons.app_registration),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Consumer<OvertimeProvider>(
          builder: (context, provider, _) {
            final profiles = provider.citizenProfiles.where((p) => p.licensePlate != null && p.licensePlate!.isNotEmpty).toList();
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
                      avatar: const Icon(Icons.card_membership, size: 16),
                      label: Text(p.licensePlate!),
                      onPressed: () => _useProfile(p),
                      backgroundColor: Colors.blue[50],
                      labelStyle: TextStyle(color: Colors.blue[800], fontSize: 12),
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
          else if (_captchaImageUrl != null)
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
                      child: Image.network(
                        _captchaImageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        CitizenLookupService().reset(LookupType.phatNguoi);
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
                    fillColor: Colors.blue[50]?.withOpacity(0.3),
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
    if (_violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(Icons.verified_user, size: 60, color: Colors.green[600]),
            const SizedBox(height: 12),
            const Text('KHÔNG CÓ VI PHẠM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 4),
            const Text('Chúc mừng! Phương tiện của bạn hiện không có lỗi vi phạm nào được ghi nhận.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
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
            const Text('DANH SÁCH VI PHẠM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
              child: Text('${_violations.length} lỗi', style: TextStyle(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _violations.length,
          itemBuilder: (context, index) {
            final v = _violations[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                title: Text(v['violation'] ?? 'Vi phạm giao thông', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                subtitle: Text('Ngày: ${v['time']}', style: const TextStyle(fontSize: 12)),
                children: [
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         _detailRow(Icons.location_on, 'Địa điểm', v['location']),
                         _detailRow(Icons.info, 'Trạng thái', v['status']),
                         _detailRow(Icons.business, 'Đơn vị xử lý', v['unit']),
                       ],
                     ),
                   )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value ?? 'Đang cập nhật', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
