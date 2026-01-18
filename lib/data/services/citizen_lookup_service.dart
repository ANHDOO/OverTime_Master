import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum LookupType { phatNguoi, mst, bhxh }

class CitizenLookupService {
  static final CitizenLookupService _instance = CitizenLookupService._internal();
  factory CitizenLookupService() => _instance;
  CitizenLookupService._internal();

  final Map<LookupType, WebViewController> _controllers = {};
  final Map<LookupType, bool> _isPrewarming = {};
  final Map<LookupType, bool> _isReady = {};

  final Map<LookupType, String> _urls = {
    LookupType.phatNguoi: 'https://phatnguoixe.com/',
    LookupType.mst: 'https://tracuunnt.gdt.gov.vn/tcnnt/mstcn.jsp',
    LookupType.bhxh: 'https://baohiemxahoi.gov.vn/tracuu/Pages/tra-cuu-ho-gia-dinh.aspx',
  };

  void prewarm(LookupType type) {
    if (_isPrewarming[type] == true || _isReady[type] == true) return;

    debugPrint('[LookupService] Pre-warming $type...');
    _isPrewarming[type] = true;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            debugPrint('[LookupService] $type ready: $url');
            _isReady[type] = true;
            _isPrewarming[type] = false;
          },
        ),
      );

    _controllers[type] = controller;
    controller.loadRequest(Uri.parse(_urls[type]!));
  }

  WebViewController? getController(LookupType type) {
    if (!_controllers.containsKey(type)) {
      prewarm(type);
    }
    return _controllers[type];
  }

  bool isReady(LookupType type) => _isReady[type] ?? false;

  void preloadAll() {
    debugPrint('[LookupService] Pre-loading all services...');
    for (var type in LookupType.values) {
      prewarm(type);
    }
  }

  void reset(LookupType type) {
    debugPrint('[LookupService] Resetting $type...');
    _isReady[type] = false;
    _isPrewarming[type] = false;
    _controllers.remove(type);
    // Don't call prewarm here, let the screen handle initialization
  }
}
