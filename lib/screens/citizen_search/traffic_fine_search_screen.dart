import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:google_fonts/google_fonts.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';

class TrafficFineSearchScreen extends StatefulWidget {
  final CitizenProfile? profile;
  const TrafficFineSearchScreen({super.key, this.profile});

  @override
  State<TrafficFineSearchScreen> createState() => _TrafficFineSearchScreenState();
}

class _TrafficFineSearchScreenState extends State<TrafficFineSearchScreen> {
  final _plateController = TextEditingController();
  String _vehicleType = '2'; // 1: Ô tô, 2: Xe máy, 3: Xe máy điện
  bool _isLoading = false;
  WebViewController? _headlessController;
  String _statusMessage = 'Đang khởi tạo...';
  bool _showResults = false;
  List<Map<String, dynamic>> _violations = [];
  String? _errorMessage;


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

    if (!service.isReady(LookupType.phatNguoi)) {
      _initHeadlessWebView();
    } else {
      setState(() {
        _statusMessage = 'Sẵn sàng tra cứu';
      });
    }
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;

    setState(() {
      _statusMessage = 'Đang kết nối đến hệ thống...';
      _errorMessage = null;
    });

    _headlessController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('phatnguoixe.com')) {
              if (mounted) {
                setState(() {
                  _statusMessage = 'Sẵn sàng tra cứu';
                });
              }
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _errorMessage = 'Lỗi kết nối: ${error.description}';
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://phatnguoixe.com/'));
  }

  Future<void> _performSearch() async {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập biển số xe')));
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang gửi yêu cầu tra cứu...';
      _errorMessage = null;
      _showResults = false;
    });

    try {
      // 1. Fill form and submit on phatnguoixe.com
      await _headlessController!.runJavaScript('''
        (function() {
          // Sử dụng ID chính xác bienso96 hoặc name="bienso"
          var plateInput = document.getElementById('bienso96') || document.querySelector('input[name="bienso"]');
          if(plateInput) plateInput.value = '${_plateController.text}';
          
          // Radio button không có ID, chọn theo name và value
          var radioBtn = document.querySelector('input[name="loaixe"][value="' + '$_vehicleType' + '"]');
          if(radioBtn) radioBtn.click();
          
          // Nút submit ID submit99
          var submitBtn = document.getElementById('submit99') || document.querySelector('input.submit');
          if(submitBtn) submitBtn.click();
        })();
      ''');

      // 2. Wait for results to load - Robust Polling
      setState(() => _statusMessage = 'Đang đợi kết quả...');
      
      bool foundActualResult = false;
      for (int i = 0; i < 15; i++) { // Max 15 seconds
        final check = await _headlessController!.runJavaScriptReturningResult('''
          (function() {
            var res = document.getElementById('resultValue');
            if (!res) return 'NOT_FOUND';
            
            // Check for table (has violations)
            if (document.querySelector('.css_table')) return 'HAS_DATA';
            
            // Check for "No violation" message
            if (res.innerText.indexOf('Không tìm thấy vi phạm') !== -1) return 'NO_DATA';
            
            // Still showing default/loading content
            return 'WAITING';
          })()
        ''');
        
        final status = check.toString().replaceAll('"', '');
        
        if (status == 'HAS_DATA' || status == 'NO_DATA') {
          foundActualResult = true;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }

      // 3. Scrape results - Lấy trực tiếp từ container để tránh nhiễu
      final resultHtmlRaw = await _headlessController!.runJavaScriptReturningResult(
        "document.getElementById('resultValue')?.outerHTML || 'NOT_FOUND'"
      );
      
      String cleanHtml = '';
      final String rawHtml = resultHtmlRaw.toString();
      

      try {
        if (rawHtml.startsWith('"') && rawHtml.endsWith('"')) {
          cleanHtml = jsonDecode(rawHtml).toString();
        } else {
          cleanHtml = rawHtml;
        }
      } catch (e) {
        cleanHtml = rawHtml;
      }

      // Làm sạch thêm nếu vẫn còn bị escape (thường gặp trên Android)
      if (cleanHtml.contains(r'\"')) {
        cleanHtml = cleanHtml.replaceAll(r'\"', '"').replaceAll(r'\n', '\n').replaceAll(r'\t', '\t');
      }

      final List<Map<String, dynamic>> violations = _parseTrafficFines(cleanHtml);

      if (mounted) {
        setState(() {
          _violations = violations;
          _showResults = true;
          _isLoading = false;
          _statusMessage = _violations.isEmpty 
              ? 'Chúc mừng! Bạn không có vi phạm nào.' 
              : 'Tìm thấy ${_violations.length} bản ghi vi phạm';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi hệ thống: $e';
          _isLoading = false;
        });
        _initHeadlessWebView();
      }
    }
  }

  /// Thuật toán "Ăn tạp" V5 - Optimized for phatnguoixe.com
  List<Map<String, dynamic>> _parseTrafficFines(String html) {
    final List<Map<String, dynamic>> results = [];
    final document = html_parser.parse(html);
    
    // 1. Khoanh vùng dữ liệu - phatnguoixe.com dùng #resultValue
    final resultContainer = document.querySelector('#resultValue') ?? document.body;
    if (resultContainer == null) {
      return results;
    }

    // Kiểm tra sớm: Nếu trang báo "Không tìm thấy vi phạm" thì return luôn
    final containerText = resultContainer.text;
    if (containerText.contains('Không tìm thấy vi phạm')) {
      return results; // Trả về danh sách rỗng
    }

    // 2. Method A: Parse theo bảng .css_table (Cấu trúc chuẩn)
    final tables = resultContainer.querySelectorAll('table.css_table');
    if (tables.isNotEmpty) {
      for (var table in tables) {
        final Map<String, String> item = {};
        final rows = table.querySelectorAll('tr');
        
        for (var row in rows) {
          // Lấy text thô và làm sạch
          final label = row.querySelector('.row_left')?.text.trim().replaceAll(':', '') ?? '';
          final value = row.querySelector('.row_right')?.text.trim() ?? '';
          
          if (label.isNotEmpty && value.isNotEmpty) {
            if (label.contains('Biển số')) item['plate'] = value;
            else if (label.contains('Thời gian')) item['time'] = value;
            else if (label.contains('Địa điểm')) item['location'] = value;
            else if (label.contains('Hành vi')) item['violation'] = value;
            else if (label.contains('Trạng thái')) item['status'] = value;
            else if (label.contains('Đơn vị')) item['unit'] = value;
          }
        }
        
        if (item.containsKey('time') || item.containsKey('violation')) {
          results.add(_createResultMap(item, results.length + 1));
        }
      }
      if (results.isNotEmpty) {
        return results;
      }
    }

    // 3. Method B: Fallback "Ăn tạp" siêu cấp (Quét text thô)
    resultContainer.querySelectorAll('br').forEach((br) => br.replaceWith(dom.Text('\n')));
    // containerText đã được khai báo ở trên, không cần khai báo lại
    
    final List<String> rawBlocks = containerText.split(RegExp(r'Biển số[:\s]*', caseSensitive: false));
    final List<String> blocks = rawBlocks.length > 1 ? rawBlocks.sublist(1) : (containerText.contains('Biển số') ? [containerText] : []);
    
    for (var block in blocks) {
      if (block.length < 30) continue;
      final Map<String, String> item = {};
      
      String? find(List<String> keywords) {
        for (var kw in keywords) {
          final pattern = RegExp('$kw[:\\s\\n]+([^\\n]+(?:\\n(?!Biển số|Thời gian|Địa điểm|Hành vi|Trạng thái|Đơn vị)[^\\n]+)*)', caseSensitive: false);
          final match = pattern.firstMatch(block);
          if (match != null) return match.group(1)?.trim();
        }
        return null;
      }

      item['plate'] = find(['Biển số']) ?? '';
      item['time'] = find(['Thời gian vi phạm', 'Thời gian']) ?? '';
      item['location'] = find(['Địa điểm vi phạm', 'Địa điểm']) ?? '';
      item['violation'] = find(['Hành vi vi phạm', 'Hành vi']) ?? '';
      item['status'] = find(['Trạng thái']) ?? '';
      item['unit'] = find(['Đơn vị phát hiện', 'Đơn vị']) ?? '';

      if (item['time']!.isNotEmpty || item['violation']!.isNotEmpty) {
        results.add(_createResultMap(item, results.length + 1));
      }
    }

    return results;
  }

  Map<String, dynamic> _createResultMap(Map<String, String> data, int index) {
    String violation = data['violation'] ?? 'Vi phạm giao thông';
    // Làm sạch mã số kỹ thuật ở đầu câu (VD: 16824.7.7.c.01.Không chấp hành...)
    final codePattern = RegExp(r'^[0-9.]+\.');
    violation = violation.replaceFirst(codePattern, '').trim();
    // Viết hoa chữ cái đầu
    if (violation.isNotEmpty) {
      violation = violation[0].toUpperCase() + violation.substring(1);
    }

    return {
      'stt': index.toString(),
      'time': data['time'] ?? 'Không rõ',
      'location': data['location'] ?? 'Không rõ',
      'violation': violation,
      'status': data['status'] ?? 'Chưa rõ',
      'unit': data['unit'] ?? 'CSGT',
    };
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMainSearchCard(),
                  if (_showResults || _errorMessage != null) ...[
                    const SizedBox(height: 32),
                    _buildResultsSection(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.blue[900],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'TRA CỨU PHẠT NGUỘI',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue[900]!, Colors.blue[600]!, Colors.blue[400]!],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -20,
              child: Icon(Icons.security, size: 200, color: Colors.white.withOpacity(0.1)),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/images/csgt_logo.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dữ liệu chính xác từ Cục CSGT',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSearchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Thông tin phương tiện',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 20),
          _buildPlateInput(),
          const SizedBox(height: 20),
          _buildVehicleTypeDropdown(),
          const SizedBox(height: 32),
          _buildSearchButton(),
        ],
      ),
    );
  }

  Widget _buildVehicleTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loại phương tiện',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _vehicleType,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.blue[900]),
              items: const [
                DropdownMenuItem(value: '1', child: Row(children: [Icon(Icons.directions_car_filled, size: 20, color: Colors.blue), SizedBox(width: 12), Text('Ô tô')])),
                DropdownMenuItem(value: '2', child: Row(children: [Icon(Icons.motorcycle, size: 20, color: Colors.orange), SizedBox(width: 12), Text('Mô tô / Xe máy')])),
                DropdownMenuItem(value: '3', child: Row(children: [Icon(Icons.electric_bike, size: 20, color: Colors.green), SizedBox(width: 12), Text('Xe máy điện')])),
              ],
              onChanged: (v) => setState(() => _vehicleType = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: _isLoading 
              ? [Colors.grey, Colors.grey[400]!] 
              : [Colors.blue[800]!, Colors.blue[600]!],
        ),
        boxShadow: [
          if (!_isLoading)
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _performSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'TRA CỨU NGAY',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResultsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLoading)
          _buildLoadingState()
        else if (_errorMessage != null)
          _buildErrorState()
        else if (_showResults)
          _buildResultsList(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          CircularProgressIndicator(color: Colors.blue[800]),
          const SizedBox(height: 20),
          Text(
            'Đang kết nối tới hệ thống...',
            style: GoogleFonts.outfit(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Đã xảy ra lỗi',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red[900]),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.red[700]),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _initHeadlessWebView,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
            style: TextButton.styleFrom(foregroundColor: Colors.red[900]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    // This is now integrated into _buildResultsSection
    return const SizedBox.shrink();
  }

  Widget _buildPlateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Biển số xe',
          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
          decoration: InputDecoration(
            hintText: 'VD: 30A12345',
            hintStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 16, color: Colors.grey[400]),
            prefixIcon: Icon(Icons.directions_car_rounded, color: Colors.blue[900]),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Consumer<OvertimeProvider>(
          builder: (context, provider, _) {
            final profiles = provider.citizenProfiles.where((p) => p.licensePlate != null && p.licensePlate!.isNotEmpty).toList();
            if (profiles.isEmpty) return const SizedBox.shrink();

            return SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final p = profiles[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(Icons.person_pin_circle, size: 14, color: Colors.blue[900]),
                      label: Text(p.licensePlate!),
                      onPressed: () => _useProfile(p),
                      backgroundColor: Colors.blue[50],
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      labelStyle: GoogleFonts.outfit(color: Colors.blue[900], fontSize: 11, fontWeight: FontWeight.w600),
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

  Widget _buildResultsList() {
    if (_violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
              child: Icon(Icons.verified_user_rounded, size: 64, color: Colors.green[600]),
            ),
            const SizedBox(height: 24),
            Text(
              'KHÔNG CÓ VI PHẠM',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
            ),
            const SizedBox(height: 12),
            Text(
              'Chúc mừng! Phương tiện của bạn hiện không có lỗi vi phạm nào được ghi nhận trên hệ thống.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey[600], height: 1.5),
            ),
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
            Text(
              'DANH SÁCH VI PHẠM',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[500],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Text(
                '${_violations.length} lỗi',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _violations.length,
          itemBuilder: (context, index) {
            final v = _violations[index];
            final bool isUnpaid = v['status']?.toString().toLowerCase().contains('chưa') ?? true;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
                ],
                border: Border.all(color: isUnpaid ? Colors.red[50]! : Colors.green[50]!, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnpaid ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isUnpaid ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: isUnpaid ? Colors.red[700] : Colors.green[700],
                      size: 24,
                    ),
                  ),
                  title: Text(
                    v['violation'] ?? 'Vi phạm giao thông',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isUnpaid ? Colors.red[900] : Colors.green[900],
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ngày: ${v['time']}',
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 24),
                          _detailRow(Icons.location_on_rounded, 'Địa điểm', v['location'], Colors.blue),
                          const SizedBox(height: 12),
                          _detailRow(
                            Icons.info_rounded, 
                            'Trạng thái', 
                            v['status'], 
                            isUnpaid ? Colors.red : Colors.green,
                            isStatus: true,
                          ),
                          const SizedBox(height: 12),
                          _detailRow(Icons.account_balance_rounded, 'Đơn vị xử lý', v['unit'], Colors.orange),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String? value, Color color, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              if (isStatus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    value ?? 'Không rõ',
                    style: GoogleFonts.outfit(fontSize: 14, color: color, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Text(
                  value ?? 'Không rõ',
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.4),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
