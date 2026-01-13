import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';

class BhxhSearchScreen extends StatefulWidget {
  final CitizenProfile? profile;
  const BhxhSearchScreen({super.key, this.profile});

  @override
  State<BhxhSearchScreen> createState() => _BhxhSearchScreenState();
}

class _BhxhSearchScreenState extends State<BhxhSearchScreen> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _dobController = TextEditingController();
  final _bhxhIdController = TextEditingController();
  
  String? _selectedProvince;
  List<Map<String, String>> _provinces = [];
  
  bool _isLoading = false;
  bool _showWebView = false;
  WebViewController? _headlessController;
  String _statusMessage = 'Sẵn sàng tra cứu';
  bool _showResults = false;
  List<Map<String, String>> _results = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initProvinces();
    if (widget.profile != null) {
      _nameController.text = widget.profile!.label;
      _idController.text = widget.profile!.cccdId ?? '';
      _bhxhIdController.text = widget.profile!.bhxhId ?? '';
    }
    _initFromService();
  }

  void _initProvinces() {
    _provinces = [
      {"text": "Thành phố Hà Nội", "value": "01TTT"},
      {"text": "Thành phố Hồ Chí Minh", "value": "79TTT"},
      {"text": "Thành phố Đà Nẵng", "value": "48TTT"},
      {"text": "Thành phố Hải Phòng", "value": "31TTT"},
      {"text": "Thành phố Cần Thơ", "value": "92TTT"},
      {"text": "Tỉnh An Giang", "value": "89TTT"},
      {"text": "Tỉnh Bà Rịa - Vũng Tàu", "value": "77TTT"},
      {"text": "Tỉnh Bắc Giang", "value": "24TTT"},
      {"text": "Tỉnh Bắc Kạn", "value": "06TTT"},
      {"text": "Tỉnh Bạc Liêu", "value": "95TTT"},
      {"text": "Tỉnh Bắc Ninh", "value": "27TTT"},
      {"text": "Tỉnh Bến Tre", "value": "83TTT"},
      {"text": "Tỉnh Bình Định", "value": "52TTT"},
      {"text": "Tỉnh Bình Dương", "value": "74TTT"},
      {"text": "Tỉnh Bình Phước", "value": "70TTT"},
      {"text": "Tỉnh Bình Thuận", "value": "60TTT"},
      {"text": "Tỉnh Cà Mau", "value": "96TTT"},
      {"text": "Tỉnh Cao Bằng", "value": "04TTT"},
      {"text": "Tỉnh Đắk Lắk", "value": "66TTT"},
      {"text": "Tỉnh Đắk Nông", "value": "67TTT"},
      {"text": "Tỉnh Điện Biên", "value": "11TTT"},
      {"text": "Tỉnh Đồng Nai", "value": "75TTT"},
      {"text": "Tỉnh Đồng Tháp", "value": "87TTT"},
      {"text": "Tỉnh Gia Lai", "value": "64TTT"},
      {"text": "Tỉnh Hà Giang", "value": "02TTT"},
      {"text": "Tỉnh Hà Nam", "value": "35TTT"},
      {"text": "Tỉnh Hà Tĩnh", "value": "42TTT"},
      {"text": "Tỉnh Hải Dương", "value": "30TTT"},
      {"text": "Tỉnh Hậu Giang", "value": "93TTT"},
      {"text": "Tỉnh Hòa Bình", "value": "17TTT"},
      {"text": "Tỉnh Hưng Yên", "value": "33TTT"},
      {"text": "Tỉnh Khánh Hòa", "value": "56TTT"},
      {"text": "Tỉnh Kiên Giang", "value": "91TTT"},
      {"text": "Tỉnh Kon Tum", "value": "62TTT"},
      {"text": "Tỉnh Lai Châu", "value": "12TTT"},
      {"text": "Tỉnh Lâm Đồng", "value": "68TTT"},
      {"text": "Tỉnh Lạng Sơn", "value": "20TTT"},
      {"text": "Tỉnh Lào Cai", "value": "10TTT"},
      {"text": "Tỉnh Long An", "value": "80TTT"},
      {"text": "Tỉnh Nam Định", "value": "36TTT"},
      {"text": "Tỉnh Nghệ An", "value": "40TTT"},
      {"text": "Tỉnh Ninh Bình", "value": "37TTT"},
      {"text": "Tỉnh Ninh Thuận", "value": "58TTT"},
      {"text": "Tỉnh Phú Thọ", "value": "25TTT"},
      {"text": "Tỉnh Phú Yên", "value": "54TTT"},
      {"text": "Tỉnh Quảng Bình", "value": "44TTT"},
      {"text": "Tỉnh Quảng Nam", "value": "49TTT"},
      {"text": "Tỉnh Quảng Ngãi", "value": "51TTT"},
      {"text": "Tỉnh Quảng Ninh", "value": "22TTT"},
      {"text": "Tỉnh Quảng Trị", "value": "45TTT"},
      {"text": "Tỉnh Sóc Trăng", "value": "94TTT"},
      {"text": "Tỉnh Sơn La", "value": "14TTT"},
      {"text": "Tỉnh Tây Ninh", "value": "72TTT"},
      {"text": "Tỉnh Thái Bình", "value": "34TTT"},
      {"text": "Tỉnh Thái Nguyên", "value": "19TTT"},
      {"text": "Tỉnh Thanh Hóa", "value": "38TTT"},
      {"text": "Tỉnh Thừa Thiên Huế", "value": "46TTT"},
      {"text": "Tỉnh Tiền Giang", "value": "82TTT"},
      {"text": "Tỉnh Trà Vinh", "value": "84TTT"},
      {"text": "Tỉnh Tuyên Quang", "value": "08TTT"},
      {"text": "Tỉnh Vĩnh Long", "value": "86TTT"},
      {"text": "Tỉnh Vĩnh Phúc", "value": "26TTT"},
      {"text": "Tỉnh Yên Bái", "value": "15TTT"},
    ];
    _provinces.sort((a, b) => a['text']!.compareTo(b['text']!));
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.bhxh);

    if (!service.isReady(LookupType.bhxh)) {
      _initHeadlessWebView();
    }
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;

    _headlessController!
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (url.contains('baohiemxahoi.gov.vn')) {
              debugPrint('[BHXH] Page loaded: $url');
              // Auto-fill if WebView is shown
              if (_showWebView) {
                _autoFillWebView();
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://baohiemxahoi.gov.vn/tracuu/Pages/tra-cuu-ho-gia-dinh.aspx'));
  }

  Future<void> _autoFillWebView() async {
    try {
      await _headlessController!.runJavaScript('''
        (function() {
          var provinceSelect = document.querySelector('select[name*="tinh"]');
          var nameInput = document.querySelector('input[name*="HoTen"]');
          var idInput = document.querySelector('input[name*="CMND"]');
          var dobInput = document.querySelector('input[name*="NgaySinh"]');
          var bhxhInput = document.querySelector('input[name*="MaCD"]');
          
          if(provinceSelect && '${_selectedProvince}' !== 'null') {
            provinceSelect.value = '${_selectedProvince}';
            provinceSelect.dispatchEvent(new Event('change', { bubbles: true }));
          }
          if(nameInput) nameInput.value = '${_nameController.text}';
          if(idInput) idInput.value = '${_idController.text}';
          if(dobInput) dobInput.value = '${_dobController.text}';
          if(bhxhInput) bhxhInput.value = '${_bhxhIdController.text}';
          
          // Focus on reCAPTCHA area
          var recaptcha = document.querySelector('.g-recaptcha');
          if(recaptcha) recaptcha.scrollIntoView();
        })()
      ''');
    } catch (e) {
      debugPrint('[BHXH] Auto-fill error: $e');
    }
  }

  Future<void> _scrapeResults() async {
    setState(() => _isLoading = true);
    try {
      final result = await _headlessController!.runJavaScriptReturningResult('''
        (function() {
          var table = document.querySelector('.table-result') || document.querySelector('table');
          if(!table) return JSON.stringify([]);
          
          var rows = table.querySelectorAll('tr');
          var data = [];
          for(var i = 1; i < rows.length; i++) {
            var cells = rows[i].querySelectorAll('td');
            if(cells.length >= 3) {
              data.push({
                'name': cells[1].innerText.trim(),
                'bhxh_id': cells[2].innerText.trim(),
                'dob': cells[3] ? cells[3].innerText.trim() : 'N/A',
                'address': cells[4] ? cells[4].innerText.trim() : 'N/A'
              });
            }
          }
          return JSON.stringify(data);
        })()
      ''');

      final List<dynamic> json = jsonDecode(result.toString().startsWith('"') ? jsonDecode(result.toString()) : result.toString());

      if (mounted) {
        setState(() {
          _results = json.map((e) => Map<String, String>.from(e as Map)).toList();
          _showResults = true;
          _isLoading = false;
          _showWebView = false;
          _statusMessage = _results.isEmpty ? 'Không tìm thấy kết quả' : 'Tìm thấy ${_results.length} kết quả';
        });
      }
    } catch (e) {
      debugPrint('[BHXH] Scrape Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi lấy dữ liệu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performSearch() async {
    if (_selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn Tỉnh/Thành phố')));
      return;
    }
    if (_nameController.text.isEmpty && _bhxhIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập Họ tên hoặc Mã BHXH')));
      return;
    }

    setState(() {
      _showWebView = true;
      _errorMessage = null;
    });
    
    _autoFillWebView();
  }

  void _useProfile(CitizenProfile profile) {
    setState(() {
      _nameController.text = profile.label;
      _idController.text = profile.cccdId ?? '';
      _bhxhIdController.text = profile.bhxhId ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tra cứu BHXH'),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(),
                const SizedBox(height: 20),
                _buildLocationSelectors(),
                const SizedBox(height: 12),
                _buildInputs(),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _performSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('TRA CỨU (MỞ WEB)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_showResults) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  _buildResultsList(),
                ],
              ],
            ),
          ),
          if (_showWebView) _buildWebViewOverlay(),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildWebViewOverlay() {
    return Container(
      color: Colors.black54,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green[800],
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Vui lòng giải reCAPTCHA và nhấn Tra cứu trên web',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: _scrapeResults,
                  child: const Text('LẤY KẾT QUẢ', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _showWebView = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: WebViewWidget(controller: _headlessController!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _errorMessage != null ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _errorMessage != null ? Colors.red[200]! : Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(_errorMessage != null ? Icons.error_outline : Icons.info_outline, color: _errorMessage != null ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Expanded(child: Text(_errorMessage ?? _statusMessage, style: TextStyle(color: _errorMessage != null ? Colors.red[800] : Colors.green[800]))),
        ],
      ),
    );
  }

  Widget _buildLocationSelectors() {
    return DropdownButtonFormField<String>(
      value: _selectedProvince,
      items: _provinces.map((e) => DropdownMenuItem(value: e['value'], child: Text(e['text']!, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => setState(() => _selectedProvince = v),
      decoration: InputDecoration(
        labelText: 'Tỉnh/Thành phố',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      isExpanded: true,
    );
  }

  Widget _buildInputs() {
    return Column(
      children: [
        _buildTextField(_nameController, 'Họ và tên', Icons.person),
        const SizedBox(height: 12),
        _buildTextField(_idController, 'Số CCCD/CMND', Icons.badge),
        const SizedBox(height: 12),
        _buildTextField(_dobController, 'Ngày sinh (DD/MM/YYYY)', Icons.calendar_today),
        const SizedBox(height: 12),
        _buildTextField(_bhxhIdController, 'Mã số BHXH', Icons.numbers),
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
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(profiles[index].label),
                    onPressed: () => _useProfile(profiles[index]),
                    backgroundColor: Colors.green[50],
                    labelStyle: TextStyle(color: Colors.green[800], fontSize: 12),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final r = _results[index];
        return Card(
          margin: const EdgeInsets.only(top: 12),
          child: ListTile(
            title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('BHXH: ${r['bhxh_id']}\nNgày sinh: ${r['dob']}\nĐịa chỉ: ${r['address']}'),
          ),
        );
      },
    );
  }
}
