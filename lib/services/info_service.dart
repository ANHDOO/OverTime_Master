import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class InfoService {
  // Methods to fetch data
  
  Future<List<Map<String, String>>> getGoldPrices() async {
    try {
      // In a real Flutter app, we might need a package like 'xml' to parse this.
      // For now, I'll return dummy data with a note, or use a simpler JSON API if available.
      return [
        {'type': 'Vàng SJC (Bán ra)', 'buy': '157.800', 'sell': '159.800'},
        {'type': 'Vàng Nhẫn 99,99', 'buy': '154.300', 'sell': '156.800'},
      ];
    } catch (e) {
      debugPrint('Error fetching gold prices: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getExchangeRates() async {
    try {
      return [
        {'code': 'USD', 'buy': '26.057', 'sell': '26.387'},
        {'code': 'EUR', 'buy': '28.100', 'sell': '28.450'},
        {'code': 'JPY', 'buy': '175.0', 'sell': '178.5'},
      ];
    } catch (e) {
      debugPrint('Error fetching exchange rates: $e');
      return [];
    }
  }

  Future<Map<String, String>> getFuelPrices() async {
    try {
      return {
        'RON 95-III': '18.560',
        'E5 RON 92': '17.650',
        'DO 0,05S': '16.420',
      };
    } catch (e) {
      debugPrint('Error fetching fuel prices: $e');
      return {};
    }
  }
}
