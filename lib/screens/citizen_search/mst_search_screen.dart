import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/citizen_profile.dart';
import '../../providers/overtime_provider.dart';
import '../../services/citizen_lookup_service.dart';
import '../../theme/app_theme.dart';

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
  Uint8List? _captchaBytes;
  String _statusMessage = 'Đang khởi tạo...';
  bool _showResults = false;
  List<Map<String, String>> _results = [];
  String? _errorMessage;
  int _retryCount = 0;

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
        _mstController.text = prefs.getString('last_mst_search') ?? '';
        _idController.text = prefs.getString('last_mst_id_search') ?? '';
      });
    }
  }

  Future<void> _saveLastSearch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_mst_search', _mstController.text);
    await prefs.setString('last_mst_id_search', _idController.text);
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.mst);
    if (service.isReady(LookupType.mst)) {
      debugPrint('[MST] Controller ready, forcing reload for fresh session');
      _initHeadlessWebView();
    } else {
      _initHeadlessWebView();
    }
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;
    setState(() { _isLoadingCaptcha = true; _captchaBytes = null; _statusMessage = 'Đang kết nối cổng Thuế...'; _errorMessage = null; });
    _headlessController!
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          if (url.contains('gdt.gov.vn')) {
            debugPrint('[MST] Page loaded: $url');
            await Future.delayed(const Duration(milliseconds: 800));
            await _extractCaptcha();
          }
        },
        onWebResourceError: (error) {
          debugPrint('[MST] WebResourceError: ${error.description}');
          if (error.description.contains('ERR_FAILED') || error.description.contains('ERR_CONNECTION_REFUSED')) return;
          if (mounted) setState(() { _errorMessage = 'Lỗi kết nối: ${error.description}'; _isLoadingCaptcha = false; });
        },
      ))
      ..loadRequest(Uri.parse('https://tracuunnt.gdt.gov.vn/tcnnt/mstcn.jsp'));
    _captchaController.clear();
  }

  Future<void> _extractCaptcha() async {
    try {
      if (!mounted) return;
      setState(() => _statusMessage = 'Đang lấy mã Captcha...');
      await Future.delayed(const Duration(seconds: 2));
      
      bool captchaReady = false;
      for (int i = 0; i < 10; i++) {
        final checkResult = await _headlessController!.runJavaScriptReturningResult('''
          (function() { var img = document.querySelector('img[src*="captcha"]'); if (!img) return 'NOT_FOUND'; if (!img.complete) return 'LOADING'; if (img.naturalWidth === 0) return 'LOADING'; return 'READY'; })()
        ''');
        if (checkResult.toString().replaceAll('"', '') == 'READY') { captchaReady = true; break; }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (!captchaReady) throw 'Captcha không tải được sau 5 giây';

      final captchaData = await _headlessController!.runJavaScriptReturningResult('''
        (function() { var img = document.querySelector('img[src*="captcha"]'); if (!img) return JSON.stringify({src: '', base64: ''}); if (!img.complete || img.naturalWidth === 0) return JSON.stringify({src: img.src, base64: 'loading'}); var canvas = document.createElement('canvas'); canvas.width = img.naturalWidth; canvas.height = img.naturalHeight; var ctx = canvas.getContext('2d'); ctx.drawImage(img, 0, 0); return JSON.stringify({src: img.src, base64: canvas.toDataURL('image/png').split(',')[1]}); })()
      ''');

      String rawJson = captchaData.toString();
      dynamic decodedData;
      try { decodedData = jsonDecode(rawJson); if (decodedData is String) decodedData = jsonDecode(decodedData); } catch (e) { if (rawJson.startsWith('{')) decodedData = jsonDecode(rawJson); else throw e; }
      if (decodedData is! Map) throw 'Decoded data is not a Map';
      final Map<String, dynamic> data = Map<String, dynamic>.from(decodedData);
      final String base64Str = data['base64'] ?? '';

      if (mounted) {
        if (base64Str.isNotEmpty && base64Str.length > 100) {
          final bytes = base64Decode(base64Str);
          setState(() { _captchaBytes = bytes; _isLoadingCaptcha = false; _statusMessage = 'Vui lòng nhập mã xác thực'; });
        } else {
          _retryCount++;
          if (_retryCount < 3) { await Future.delayed(const Duration(seconds: 1)); await _extractCaptcha(); }
          else setState(() { _errorMessage = 'Không tìm thấy mã xác thực trên trang.'; _isLoadingCaptcha = false; });
        }
      }
    } catch (e) {
      debugPrint('[MST] Extract Captcha Error: $e');
      if (mounted) setState(() { _errorMessage = 'Lỗi xử lý Captcha: $e'; _isLoadingCaptcha = false; });
    }
  }

  Future<void> _performSearch() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_mstController.text.isEmpty && _idController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_rounded, color: Colors.white), const SizedBox(width: 10), const Text('Vui lòng nhập MST hoặc Số CCCD')]), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)));
      return;
    }
    if (_captchaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_rounded, color: Colors.white), const SizedBox(width: 10), const Text('Vui lòng nhập mã Captcha')]), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)));
      return;
    }

    setState(() { _isLoading = true; _statusMessage = 'Đang tra cứu dữ liệu...'; _errorMessage = null; _showResults = false; });
    _saveLastSearch();

    try {
      final fillResult = await _headlessController!.runJavaScriptReturningResult('''
        (function() { var mstInput = document.querySelector('input[name="mst"]'); var idInput = document.querySelector('input[name="idCard"]') || document.querySelector('input[name="cmt"]') || document.querySelector('input[name="cmnd"]') || document.querySelector('input[name="cccd"]'); var captchaInput = document.querySelector('input[name="captcha"]'); if(mstInput) mstInput.value = '${_mstController.text}'; if(idInput) idInput.value = '${_idController.text}'; if(captchaInput) captchaInput.value = '${_captchaController.text}'; return 'done'; })()
      ''');

      await _headlessController!.runJavaScript('var form = document.myform || document.forms[0]; if(form) form.submit();');
      await Future.delayed(const Duration(seconds: 3));
      
      for (int i = 0; i < 5; i++) {
        final pageCheck = await _headlessController!.runJavaScriptReturningResult('''(function() { if (document.body.innerText.includes('Sai mã xác nhận')) return 'CAPTCHA_ERROR'; if (document.body.innerText.includes('BẢNG THÔNG TIN')) return 'HAS_DATA'; if (document.body.innerText.includes('Không tìm thấy')) return 'NO_DATA'; return 'WAITING'; })()''');
        if (pageCheck.toString().replaceAll('"', '') != 'WAITING') break;
        await Future.delayed(const Duration(seconds: 1));
      }

      final errorCheck = await _headlessController!.runJavaScriptReturningResult("document.body.innerText.includes('Sai mã xác nhận')");
      if (errorCheck.toString() == 'true') {
        if (mounted) { setState(() { _errorMessage = 'Mã xác thực không chính xác'; _isLoading = false; }); _retryCount = 0; _initHeadlessWebView(); }
        return;
      }

      final result = await _headlessController!.runJavaScriptReturningResult('''
        (function() { var tables = document.querySelectorAll('table'); var data = []; for(var t = 0; t < tables.length; t++) { var rows = tables[t].querySelectorAll('tr'); for(var i = 0; i < rows.length; i++) { var cells = rows[i].querySelectorAll('td'); if(cells.length >= 4) { for(var c = 0; c < cells.length; c++) { var cellText = cells[c]?.innerText?.trim() || ''; if(/^[0-9]{9,}/.test(cellText)) { data.push({'mst': cells[1]?.innerText?.trim() || '', 'name': cells[2]?.innerText?.trim() || '', 'agency': cells[3]?.innerText?.trim() || '', 'status': cells[4]?.innerText?.trim() || 'Đang hoạt động'}); break; } } } } } return JSON.stringify(data); })()
      ''');

      final resultStr = result.toString();
      final cleanJson = resultStr.startsWith('"') && resultStr.endsWith('"') ? resultStr.substring(1, resultStr.length - 1).replaceAll(r'\"', '"') : resultStr;
      final List<dynamic> json = jsonDecode(cleanJson);

      if (mounted) {
        setState(() { _results = json.map((e) => Map<String, String>.from(e as Map)).toList(); _showResults = true; _isLoading = false; _statusMessage = _results.isEmpty ? 'Không tìm thấy thông tin' : 'Tìm thấy ${_results.length} kết quả'; });
      }
    } catch (e) {
      debugPrint('[MST] Search Error: $e');
      if (mounted) { setState(() { _errorMessage = 'Lỗi hệ thống: $e'; _isLoading = false; }); _initHeadlessWebView(); }
    }
  }

  void _useProfile(CitizenProfile profile) {
    setState(() { _mstController.text = profile.taxId ?? profile.cccdId ?? ''; _idController.text = profile.cccdId ?? ''; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chọn: ${profile.label}'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(title: const Text('Tra cứu Mã số thuế')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusHeader(isDark),
            const SizedBox(height: 20),
            _buildInputs(isDark),
            const SizedBox(height: 20),
            _buildCaptchaSection(isDark),
            const SizedBox(height: 24),
            _buildSearchButton(isDark),
            if (_showResults) ...[const SizedBox(height: 24), _buildResultsList(isDark)],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(bool isDark) {
    Color bgColor = _errorMessage != null ? AppColors.danger : (_showResults ? AppColors.success : AppColors.danger);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (_isLoading || _isLoadingCaptcha)
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: bgColor))
          else
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: bgColor.withValues(alpha: 0.2), borderRadius: AppRadius.borderSm), child: Icon(_errorMessage != null ? Icons.error_rounded : (_showResults ? Icons.check_circle_rounded : Icons.info_rounded), color: bgColor, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Text(_errorMessage ?? _statusMessage, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w500))),
          if (_errorMessage != null)
            IconButton(onPressed: _initHeadlessWebView, icon: Icon(Icons.refresh_rounded, color: bgColor)),
        ],
      ),
    );
  }

  Widget _buildInputs(bool isDark) {
    return Column(
      children: [
        _buildTextField(_mstController, 'Mã số thuế', Icons.numbers_rounded, isDark),
        const SizedBox(height: 12),
        _buildTextField(_idController, 'Số CCCD/CMND', Icons.badge_rounded, isDark),
        const SizedBox(height: 12),
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
                    child: InkWell(
                      onTap: () => _useProfile(p),
                      borderRadius: AppRadius.borderFull,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderFull, border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
                        child: Row(children: [Icon(Icons.person_rounded, size: 16, color: AppColors.danger), const SizedBox(width: 6), Text(p.label, style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12))]),
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
      keyboardType: TextInputType.number,
      style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        prefixIcon: Icon(icon, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.danger, width: 2)),
      ),
    );
  }

  Widget _buildCaptchaSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.security_rounded, color: AppColors.danger, size: 18),
            const SizedBox(width: 10),
            Text('Xác thực bảo mật', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
          ]),
          const SizedBox(height: 16),
          if (_isLoadingCaptcha)
            Center(child: Padding(padding: const EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.danger)))
          else if (_captchaBytes != null)
            Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  height: 55,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant, borderRadius: AppRadius.borderMd, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                  child: Image.memory(_captchaBytes!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 40)),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderFull),
                  child: IconButton(
                    onPressed: () { CitizenLookupService().reset(LookupType.mst); _retryCount = 0; _captchaBytes = null; _initFromService(); },
                    icon: Icon(Icons.refresh_rounded, color: AppColors.danger),
                    tooltip: 'Đổi mã khác',
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: _captchaController,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 6, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Nhập mã xác thực',
                  hintStyle: TextStyle(fontSize: 14, letterSpacing: 0, fontWeight: FontWeight.normal, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  filled: true,
                  fillColor: AppColors.danger.withValues(alpha: isDark ? 0.1 : 0.05),
                  border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.danger.withValues(alpha: 0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.danger, width: 2)),
                ),
              ),
            ])
          else
            Center(child: Text('Lỗi tải Captcha', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildSearchButton(bool isDark) {
    return Container(
      decoration: BoxDecoration(gradient: AppGradients.heroDanger, borderRadius: AppRadius.borderMd, boxShadow: AppShadows.heroDangerLight),
      child: ElevatedButton(
        onPressed: (_isLoading || _isLoadingCaptcha) ? null : _performSearch,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.search_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(_isLoading ? 'Đang tra cứu...' : 'TRA CỨU', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
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
            Text('Không tìm thấy thông tin người nộp thuế với dữ liệu đã nhập.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13)),
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
                  Text(r['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.danger)),
                  const SizedBox(height: 12),
                  _detailRow(Icons.numbers_rounded, 'MST', r['mst'], isDark),
                  _detailRow(Icons.business_rounded, 'Cơ quan thuế', r['agency'], isDark),
                  _detailRow(Icons.check_circle_rounded, 'Trạng thái', r['status'], isDark),
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
