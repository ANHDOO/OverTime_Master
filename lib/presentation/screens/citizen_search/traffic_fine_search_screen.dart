import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../../data/models/citizen_profile.dart';
import '../../../logic/providers/citizen_profile_provider.dart';
import '../../../data/services/citizen_lookup_service.dart';
import '../../../core/theme/app_theme.dart';

class TrafficFineSearchScreen extends StatefulWidget {
  final CitizenProfile? profile;
  const TrafficFineSearchScreen({super.key, this.profile});

  @override
  State<TrafficFineSearchScreen> createState() => _TrafficFineSearchScreenState();
}

class _TrafficFineSearchScreenState extends State<TrafficFineSearchScreen> {
  final _plateController = TextEditingController();
  String _vehicleType = '2';
  bool _isLoading = false;
  WebViewController? _headlessController;
  bool _showResults = false;
  List<Map<String, dynamic>> _violations = [];
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
        _plateController.text = prefs.getString('last_traffic_plate_search') ?? '';
        _vehicleType = prefs.getString('last_traffic_vehicle_type') ?? '2';
      });
    }
  }

  Future<void> _saveLastSearch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_traffic_plate_search', _plateController.text);
    await prefs.setString('last_traffic_vehicle_type', _vehicleType);
  }

  void _initFromService() {
    final service = CitizenLookupService();
    _headlessController = service.getController(LookupType.phatNguoi);
    if (!service.isReady(LookupType.phatNguoi)) _initHeadlessWebView();
  }

  void _initHeadlessWebView() {
    if (_headlessController == null) return;
    setState(() { _errorMessage = null; });
    _headlessController!
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async { if (url.contains('phatnguoixe.com') && mounted) setState(() => {}); },
        onWebResourceError: (error) { if (mounted) setState(() => _errorMessage = 'Lỗi kết nối: ${error.description}'); },
      ))
      ..loadRequest(Uri.parse('https://phatnguoixe.com/'));
  }

  Future<void> _performSearch() async {
    if (_plateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_rounded, color: Colors.white), const SizedBox(width: 10), const Text('Vui lòng nhập biển số xe')]), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)));
      return;
    }
    setState(() { _isLoading = true; _errorMessage = null; _showResults = false; });
    _saveLastSearch();

    try {
      await _headlessController!.runJavaScript('''
        (function() { var plateInput = document.getElementById('bienso96') || document.querySelector('input[name="bienso"]'); if(plateInput) plateInput.value = '${_plateController.text}'; var radioBtn = document.querySelector('input[name="loaixe"][value="' + '$_vehicleType' + '"]'); if(radioBtn) radioBtn.click(); var submitBtn = document.getElementById('submit99') || document.querySelector('input.submit'); if(submitBtn) submitBtn.click(); })();
      ''');
      
      for (int i = 0; i < 15; i++) {
        final check = await _headlessController!.runJavaScriptReturningResult('''(function() { var res = document.getElementById('resultValue'); if (!res) return 'NOT_FOUND'; if (document.querySelector('.css_table')) return 'HAS_DATA'; if (res.innerText.indexOf('Không tìm thấy vi phạm') !== -1) return 'NO_DATA'; return 'WAITING'; })()''');
        if (['HAS_DATA', 'NO_DATA'].contains(check.toString().replaceAll('"', ''))) { break; }
        await Future.delayed(const Duration(seconds: 1));
      }

      final resultHtmlRaw = await _headlessController!.runJavaScriptReturningResult("document.getElementById('resultValue')?.outerHTML || 'NOT_FOUND'");
      String cleanHtml = '';
      final String rawHtml = resultHtmlRaw.toString();
      try { cleanHtml = rawHtml.startsWith('"') && rawHtml.endsWith('"') ? jsonDecode(rawHtml).toString() : rawHtml; } catch (e) { cleanHtml = rawHtml; }
      if (cleanHtml.contains(r'\"')) cleanHtml = cleanHtml.replaceAll(r'\"', '"').replaceAll(r'\n', '\n').replaceAll(r'\t', '\t');
      
      final List<Map<String, dynamic>> violations = _parseTrafficFines(cleanHtml);
      if (mounted) setState(() { _violations = violations; _showResults = true; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() { _errorMessage = 'Lỗi hệ thống: $e'; _isLoading = false; }); _initHeadlessWebView(); }
    }
  }

  List<Map<String, dynamic>> _parseTrafficFines(String html) {
    final List<Map<String, dynamic>> results = [];
    final document = html_parser.parse(html);
    final resultContainer = document.querySelector('#resultValue') ?? document.body;
    if (resultContainer == null) return results;
    final containerText = resultContainer.text;
    if (containerText.contains('Không tìm thấy vi phạm')) return results;

    final tables = resultContainer.querySelectorAll('table.css_table');
    if (tables.isNotEmpty) {
      for (var table in tables) {
        final Map<String, String> item = {};
        final rows = table.querySelectorAll('tr');
        for (var row in rows) {
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
        if (item.containsKey('time') || item.containsKey('violation')) results.add(_createResultMap(item, results.length + 1));
      }
      if (results.isNotEmpty) return results;
    }

    resultContainer.querySelectorAll('br').forEach((br) => br.replaceWith(dom.Text('\n')));
    final List<String> rawBlocks = containerText.split(RegExp(r'Biển số[:\s]*', caseSensitive: false));
    final List<String> blocks = rawBlocks.length > 1 ? rawBlocks.sublist(1) : (containerText.contains('Biển số') ? [containerText] : []);
    for (var block in blocks) {
      if (block.length < 30) continue;
      final Map<String, String> item = {};
      String? find(List<String> keywords) { for (var kw in keywords) { final pattern = RegExp('$kw[:\\s\\n]+([^\\n]+(?:\\n(?!Biển số|Thời gian|Địa điểm|Hành vi|Trạng thái|Đơn vị)[^\\n]+)*)', caseSensitive: false); final match = pattern.firstMatch(block); if (match != null) return match.group(1)?.trim(); } return null; }
      item['plate'] = find(['Biển số']) ?? '';
      item['time'] = find(['Thời gian vi phạm', 'Thời gian']) ?? '';
      item['location'] = find(['Địa điểm vi phạm', 'Địa điểm']) ?? '';
      item['violation'] = find(['Hành vi vi phạm', 'Hành vi']) ?? '';
      item['status'] = find(['Trạng thái']) ?? '';
      item['unit'] = find(['Đơn vị phát hiện', 'Đơn vị']) ?? '';
      if (item['time']!.isNotEmpty || item['violation']!.isNotEmpty) results.add(_createResultMap(item, results.length + 1));
    }
    return results;
  }

  Map<String, dynamic> _createResultMap(Map<String, String> data, int index) {
    String violation = data['violation'] ?? 'Vi phạm giao thông';
    final codePattern = RegExp(r'^[0-9.]+\.');
    violation = violation.replaceFirst(codePattern, '').trim();
    if (violation.isNotEmpty) violation = violation[0].toUpperCase() + violation.substring(1);
    return {'stt': index.toString(), 'time': data['time'] ?? 'Không rõ', 'location': data['location'] ?? 'Không rõ', 'violation': violation, 'status': data['status'] ?? 'Chưa rõ', 'unit': data['unit'] ?? 'CSGT'};
  }

  void _useProfile(CitizenProfile profile) {
    if (profile.licensePlate != null) {
      setState(() => _plateController.text = profile.licensePlate!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã chọn biển số: ${profile.licensePlate}'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd), backgroundColor: AppColors.success));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMainSearchCard(isDark),
                  if (_showResults || _errorMessage != null) ...[const SizedBox(height: 32), _buildResultsSection(isDark)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 220.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: const Text('TRA CỨU PHẠT NGUỘI', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1, color: Colors.white)),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(decoration: BoxDecoration(gradient: AppGradients.heroBlue)),
            // Logo CSGT chìm phía sau
            Positioned(
              right: -20,
              top: 20,
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/csgt_logo.png',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 45),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/csgt_logo.png',
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text(
                      'Dữ liệu chính xác từ Cục CSGT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainSearchCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderXl, boxShadow: isDark ? null : AppShadows.cardLight, border: isDark ? Border.all(color: AppColors.darkBorder) : null),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Icon(Icons.search_rounded, color: AppColors.primary, size: 20), const SizedBox(width: 10), Text('Thông tin phương tiện', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary))]),
          const SizedBox(height: 20),
          _buildPlateInput(isDark),
          const SizedBox(height: 20),
          _buildVehicleTypeDropdown(isDark),
          const SizedBox(height: 24),
          _buildSearchButton(isDark),
        ],
      ),
    );
  }

  Widget _buildPlateInput(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Biển số xe', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, letterSpacing: 2, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          decoration: InputDecoration(
            hintText: 'VD: 30A12345',
            hintStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            prefixIcon: Icon(Icons.directions_car_rounded, color: AppColors.primary),
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant,
            border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 12),
        Consumer<CitizenProfileProvider>(
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
                    child: InkWell(
                      onTap: () => _useProfile(p),
                      borderRadius: AppRadius.borderFull,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderFull, border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
                        child: Row(children: [Icon(Icons.person_pin_circle_rounded, size: 14, color: AppColors.primary), const SizedBox(width: 6), Text(p.licensePlate!, style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600))]),
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

  Widget _buildVehicleTypeDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loại phương tiện', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant, borderRadius: AppRadius.borderMd, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _vehicleType,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              items: [
                DropdownMenuItem(value: '1', child: Row(children: [Icon(Icons.directions_car_filled_rounded, size: 20, color: AppColors.primary), const SizedBox(width: 12), Text('Ô tô', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))])),
                DropdownMenuItem(value: '2', child: Row(children: [Icon(Icons.motorcycle_rounded, size: 20, color: AppColors.accent), const SizedBox(width: 12), Text('Mô tô / Xe máy', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))])),
                DropdownMenuItem(value: '3', child: Row(children: [Icon(Icons.electric_bike_rounded, size: 20, color: AppColors.success), const SizedBox(width: 12), Text('Xe máy điện', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))])),
              ],
              onChanged: (v) => setState(() => _vehicleType = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton(bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(gradient: _isLoading ? null : AppGradients.heroBlue, color: _isLoading ? (isDark ? AppColors.darkBorder : AppColors.lightBorder) : null, borderRadius: AppRadius.borderMd, boxShadow: _isLoading ? null : AppShadows.heroLight),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _performSearch,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd)),
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.search_rounded, color: Colors.white), const SizedBox(width: 12), const Text('TRA CỨU NGAY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white))]),
      ),
    );
  }

  Widget _buildResultsSection(bool isDark) {
    if (_isLoading) return _buildLoadingState(isDark);
    if (_errorMessage != null) return _buildErrorState(isDark);
    if (_showResults) return _buildResultsList(isDark);
    return const SizedBox.shrink();
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(child: Column(children: [const SizedBox(height: 40), CircularProgressIndicator(color: AppColors.primary), const SizedBox(height: 20), Text('Đang kết nối tới hệ thống...', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))]));
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: AppRadius.borderXl, border: Border.all(color: AppColors.danger.withValues(alpha: 0.3))),
      child: Column(children: [
        Icon(Icons.error_rounded, color: AppColors.danger, size: 48),
        const SizedBox(height: 16),
        Text('Đã xảy ra lỗi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.danger)),
        const SizedBox(height: 8),
        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        const SizedBox(height: 20),
        TextButton.icon(onPressed: _initHeadlessWebView, icon: Icon(Icons.refresh_rounded, color: AppColors.danger), label: Text('Thử lại', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _buildResultsList(bool isDark) {
    if (_violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderXl, boxShadow: isDark ? null : AppShadows.cardLight, border: isDark ? Border.all(color: AppColors.darkBorder) : null),
        child: Column(children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.1), shape: BoxShape.circle), child: Icon(Icons.verified_user_rounded, size: 64, color: AppColors.success)),
          const SizedBox(height: 24),
          Text('KHÔNG CÓ VI PHẠM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.success)),
          const SizedBox(height: 12),
          Text('Chúc mừng! Phương tiện của bạn hiện không có lỗi vi phạm nào được ghi nhận trên hệ thống.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, height: 1.5)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('DANH SÁCH VI PHẠM', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(gradient: AppGradients.heroDanger, borderRadius: AppRadius.borderFull, boxShadow: [BoxShadow(color: AppColors.danger.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]), child: Text('${_violations.length} lỗi', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _violations.length,
          itemBuilder: (context, index) {
            final v = _violations[index];
            final bool isUnpaid = v['status']?.toString().toLowerCase().contains('chưa') ?? true;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderXl, boxShadow: isDark ? null : AppShadows.cardLight, border: Border.all(color: isUnpaid ? AppColors.danger.withValues(alpha: 0.3) : AppColors.success.withValues(alpha: 0.3))),
              child: ClipRRect(
                borderRadius: AppRadius.borderXl,
                child: ExpansionTile(
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  collapsedBackgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isUnpaid ? AppColors.danger.withValues(alpha: isDark ? 0.2 : 0.1) : AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderMd), child: Icon(isUnpaid ? Icons.warning_rounded : Icons.check_circle_rounded, color: isUnpaid ? AppColors.danger : AppColors.success, size: 24)),
                  title: Text(v['violation'] ?? 'Vi phạm giao thông', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isUnpaid ? AppColors.danger : AppColors.success)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ngày: ${v['time']}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        _detailRow(Icons.location_on_rounded, 'Địa điểm', v['location'], AppColors.primary, isDark),
                        const SizedBox(height: 12),
                        _detailRow(Icons.info_rounded, 'Trạng thái', v['status'], isUnpaid ? AppColors.danger : AppColors.success, isDark, isStatus: true),
                        const SizedBox(height: 12),
                        _detailRow(Icons.account_balance_rounded, 'Đơn vị xử lý', v['unit'], AppColors.accent, isDark),
                      ]),
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

  Widget _detailRow(IconData icon, String label, String? value, Color color, bool isDark, {bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            if (isStatus)
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: color.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: AppRadius.borderSm), child: Text(value ?? 'Không rõ', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)))
            else
              Text(value ?? 'Không rõ', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w500, height: 1.4)),
          ]),
        ),
      ],
    );
  }
}
