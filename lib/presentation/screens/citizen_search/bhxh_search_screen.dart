import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/models/citizen_profile.dart';
import '../../../logic/providers/citizen_profile_provider.dart';
import '../../../data/services/citizen_lookup_service.dart';
import '../../../core/theme/app_theme.dart';

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
    _initFromService();
    _loadLastSearch();
  }

  Future<void> _loadLastSearch() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted && widget.profile == null) {
      setState(() {
        _selectedProvince = prefs.getString('last_bhxh_province');
        _nameController.text = prefs.getString('last_bhxh_name') ?? '';
        _idController.text = prefs.getString('last_bhxh_id_card') ?? '';
        _dobController.text = prefs.getString('last_bhxh_dob') ?? '';
        _bhxhIdController.text = prefs.getString('last_bhxh_bhxh_id') ?? '';
      });
    }
  }

  Future<void> _saveLastSearch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_bhxh_province', _selectedProvince ?? '');
    await prefs.setString('last_bhxh_name', _nameController.text);
    await prefs.setString('last_bhxh_id_card', _idController.text);
    await prefs.setString('last_bhxh_dob', _dobController.text);
    await prefs.setString('last_bhxh_bhxh_id', _bhxhIdController.text);
  }


  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.bhxh);
    if (!service.isReady(LookupType.bhxh)) _initHeadlessWebView();
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;
    _headlessController!
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          if (url.contains('baohiemxahoi.gov.vn')) {
            debugPrint('[BHXH] Page loaded: $url');
            if (_showWebView) _autoFillWebView();
          }
        },
      ))
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
          if(provinceSelect && '${_selectedProvince}' !== 'null') { provinceSelect.value = '${_selectedProvince}'; provinceSelect.dispatchEvent(new Event('change', { bubbles: true })); }
          if(nameInput) nameInput.value = '${_nameController.text}';
          if(idInput) idInput.value = '${_idController.text}';
          if(dobInput) dobInput.value = '${_dobController.text}';
          if(bhxhInput) bhxhInput.value = '${_bhxhIdController.text}';
          var recaptcha = document.querySelector('.g-recaptcha');
          if(recaptcha) recaptcha.scrollIntoView();
        })()
      ''');
    } catch (e) { debugPrint('[BHXH] Auto-fill error: $e'); }
  }

  Future<void> _scrapeResults() async {
    setState(() => _isLoading = true);
    try {
      final result = await _headlessController!.runJavaScriptReturningResult('''
        (function() { var table = document.querySelector('.table-result') || document.querySelector('table'); if(!table) return JSON.stringify([]); var rows = table.querySelectorAll('tr'); var data = []; for(var i = 1; i < rows.length; i++) { var cells = rows[i].querySelectorAll('td'); if(cells.length >= 3) { data.push({'name': cells[1].innerText.trim(), 'bhxh_id': cells[2].innerText.trim(), 'dob': cells[3] ? cells[3].innerText.trim() : 'N/A', 'address': cells[4] ? cells[4].innerText.trim() : 'N/A'}); } } return JSON.stringify(data); })()
      ''');
      final List<dynamic> json = jsonDecode(result.toString().startsWith('"') ? jsonDecode(result.toString()) : result.toString());
      if (mounted) setState(() { _results = json.map((e) => Map<String, String>.from(e as Map)).toList(); _showResults = true; _isLoading = false; _showWebView = false; _statusMessage = _results.isEmpty ? 'Không tìm thấy kết quả' : 'Tìm thấy ${_results.length} kết quả'; });
    } catch (e) {
      debugPrint('[BHXH] Scrape Error: $e');
      if (mounted) setState(() { _errorMessage = 'Lỗi lấy dữ liệu: $e'; _isLoading = false; });
    }
  }

  Future<void> _performSearch() async {
    if (_selectedProvince == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_rounded, color: Colors.white), const SizedBox(width: 10), const Text('Vui lòng chọn Tỉnh/Thành phố')]), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)));
      return;
    }
    if (_nameController.text.isEmpty && _bhxhIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_rounded, color: Colors.white), const SizedBox(width: 10), const Text('Vui lòng nhập Họ tên hoặc Mã BHXH')]), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)));
      return;
    }
    setState(() { _showWebView = true; _errorMessage = null; });
    _saveLastSearch();
    _autoFillWebView();
  }

  void _useProfile(CitizenProfile profile) {
    setState(() { _nameController.text = profile.label; _idController.text = profile.cccdId ?? ''; _bhxhIdController.text = profile.bhxhId ?? ''; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chọn: ${profile.label}'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(title: const Text('Tra cứu BHXH')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatusHeader(isDark),
                const SizedBox(height: 20),
                _buildLocationSelector(isDark),
                const SizedBox(height: 16),
                _buildInputs(isDark),
                const SizedBox(height: 24),
                _buildSearchButton(isDark),
                if (_showResults) ...[const SizedBox(height: 24), _buildResultsList(isDark)],
              ],
            ),
          ),
          if (_showWebView) _buildWebViewOverlay(isDark),
          if (_isLoading) Container(color: Colors.black26, child: Center(child: CircularProgressIndicator(color: AppColors.success))),
        ],
      ),
    );
  }

  Widget _buildWebViewOverlay(bool isDark) {
    return Container(
      color: Colors.black54,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(gradient: AppGradients.heroGreen),
            child: Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Vui lòng giải reCAPTCHA', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Nhấn Tra cứu trên web rồi lấy kết quả', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                ])),
                Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: AppRadius.borderMd),
                  child: TextButton(onPressed: _scrapeResults, child: const Text('LẤY KẾT QUẢ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => setState(() => _showWebView = false)),
              ],
            ),
          ),
          Expanded(child: Container(color: Colors.white, child: WebViewWidget(controller: _headlessController!))),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(bool isDark) {
    Color bgColor = _errorMessage != null ? AppColors.danger : (_showResults ? AppColors.success : AppColors.success);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bgColor.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: AppRadius.borderLg, border: Border.all(color: bgColor.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.2), borderRadius: AppRadius.borderSm), child: Icon(_errorMessage != null ? Icons.error_rounded : (_showResults ? Icons.check_circle_rounded : Icons.health_and_safety_rounded), color: bgColor, size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Text(_errorMessage ?? _statusMessage, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderMd, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      child: DropdownButtonFormField<String>(
        value: _selectedProvince,
        items: _provinces.map((e) => DropdownMenuItem(value: e['value'], child: Text(e['text']!, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 14)))).toList(),
        onChanged: (v) => setState(() => _selectedProvince = v),
        decoration: InputDecoration(labelText: 'Tỉnh/Thành phố', labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), border: InputBorder.none, prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.success)),
        isExpanded: true,
        dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.success),
      ),
    );
  }

  Widget _buildInputs(bool isDark) {
    return Column(
      children: [
        _buildTextField(_nameController, 'Họ và tên', Icons.person_rounded, isDark),
        const SizedBox(height: 12),
        _buildTextField(_idController, 'Số CCCD/CMND', Icons.badge_rounded, isDark),
        const SizedBox(height: 12),
        _buildTextField(_dobController, 'Ngày sinh (DD/MM/YYYY)', Icons.calendar_today_rounded, isDark),
        const SizedBox(height: 12),
        _buildTextField(_bhxhIdController, 'Mã số BHXH', Icons.numbers_rounded, isDark),
        const SizedBox(height: 12),
        Consumer<CitizenProfileProvider>(
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
                    child: InkWell(
                      onTap: () => _useProfile(p),
                      borderRadius: AppRadius.borderFull,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderFull, border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                        child: Row(children: [Icon(Icons.person_rounded, size: 16, color: AppColors.success), const SizedBox(width: 6), Text(p.label, style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12))]),
                      ),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, size: 20),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.success, width: 2)),
      ),
    );
  }

  Widget _buildSearchButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.heroGreen, borderRadius: AppRadius.borderMd, boxShadow: AppShadows.heroGreenLight),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _performSearch,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Text('TRA CỨU (MỞ WEB)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(bool isDark) {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: AppRadius.borderLg, border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.warning),
            const SizedBox(height: 12),
            Text('KHÔNG TÌM THẤY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warning)),
            const SizedBox(height: 6),
            Text('Không tìm thấy dữ liệu BHXH với thông tin đã nhập.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [Icon(Icons.list_alt_rounded, color: AppColors.success, size: 20), const SizedBox(width: 10), Text('KẾT QUẢ TRA CỨU', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderFull), child: Text('${_results.length} kết quả', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            final r = _results[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderLg, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.success)),
                  const SizedBox(height: 12),
                  _detailRow(Icons.numbers_rounded, 'BHXH', r['bhxh_id'], isDark),
                  _detailRow(Icons.calendar_today_rounded, 'Ngày sinh', r['dob'], isDark),
                  _detailRow(Icons.location_on_rounded, 'Địa chỉ', r['address'], isDark),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String? value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          Expanded(child: Text(value ?? 'N/A', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
        ],
      ),
    );
  }
}
