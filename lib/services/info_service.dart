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
        {'type': 'SJC 1L, 10L', 'buy': '82.000', 'sell': '85.000'},
        {'type': 'Nhẫn SJC 99,99', 'buy': '81.500', 'sell': '83.000'},
      ];
    } catch (e) {
      debugPrint('Error fetching gold prices: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getExchangeRates() async {
    try {
      return [
        {'code': 'USD', 'buy': '25.200', 'sell': '25.500'},
        {'code': 'EUR', 'buy': '27.100', 'sell': '27.400'},
        {'code': 'JPY', 'buy': '165.0', 'sell': '168.0'},
      ];
    } catch (e) {
      debugPrint('Error fetching exchange rates: $e');
      return [];
    }
  }

  Future<Map<String, String>> getFuelPrices() async {
    try {
      return {
        'RON 95-V': '23.560',
        'RON 95-III': '22.700',
        'E5 RON 92': '21.480',
        'DO 0,05S': '18.630',
      };
    } catch (e) {
      debugPrint('Error fetching fuel prices: $e');
      return {};
    }
  }
}
