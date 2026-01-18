import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as parser;
import '../../core/constants/api_constants.dart';

class InfoService {
  // Custom client to handle SSL certificate issues (common with some VN websites)
  final http.Client _client = IOClient(
    HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
  );

  Future<Map<String, List<Map<String, String>>>> getTamNhungGoldPrices() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConstants.goldPriceUrl),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var tables = document.querySelectorAll('table.goldbox-table');
        
        final Map<String, List<Map<String, String>>> result = {
          'mao_thiet': [],
          'sjc': [],
        };

        // Table 1: Mao Thiet Prices
        if (tables.isNotEmpty) {
          var rows = tables[0].querySelectorAll('tbody tr');
          for (var row in rows) {
            var cols = row.querySelectorAll('td');
            if (cols.length >= 3) {
              result['mao_thiet']!.add({
                'type': cols[0].text.trim(),
                'buy': cols[1].text.trim(),
                'sell': cols[2].text.trim(),
              });
            }
          }
        }

        // Table 2: SJC Prices
        if (tables.length >= 2) {
          var rows = tables[1].querySelectorAll('tbody tr');
          for (var row in rows) {
            var cols = row.querySelectorAll('td');
            if (cols.length >= 3) {
              result['sjc']!.add({
                'type': cols[0].text.trim(),
                'buy': cols[1].text.trim(),
                'sell': cols[2].text.trim(),
              });
            }
          }
        }

        return result;
      }
      debugPrint('Failed to fetch gold prices: Status ${response.statusCode}');
      return {'mao_thiet': [], 'sjc': []};
    } catch (e) {
      debugPrint('Error fetching gold prices: $e');
      return {'mao_thiet': [], 'sjc': []};
    }
  }

  Future<List<Map<String, String>>> getMiHongGoldPrices() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConstants.miHongGoldUrl),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var table = document.querySelector('#tblCurrentPrice');
        if (table != null) {
          var rows = table.querySelectorAll('tr');
          final List<Map<String, String>> prices = [];
          
          // Skip header row
          for (var i = 1; i < rows.length; i++) {
            var cols = rows[i].querySelectorAll('td');
            if (cols.length >= 4) {
              // First item in row
              prices.add({
                'type': cols[0].text.trim(),
                'buy': cols[2].text.trim(),
                'sell': cols[3].text.trim(),
              });
              
              // Second item in row (if exists)
              if (cols.length >= 8) {
                prices.add({
                  'type': cols[4].text.trim(),
                  'buy': cols[6].text.trim(),
                  'sell': cols[7].text.trim(),
                });
              }
            }
          }
          return prices;
        }
      }
      debugPrint('Failed to fetch Mi Hong prices: Status ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error fetching Mi Hong gold prices: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> getExchangeRates() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConstants.exchangeRateUrl),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final xmlString = response.body;
        final List<Map<String, String>> result = [];
        
        final exrateRegex = RegExp(r'<Exrate\s+CurrencyCode="([^"]*)"[^>]*CurrencyName="([^"]*)"[^>]*Buy="([^"]*)"[^>]*Transfer="([^"]*)"[^>]*Sell="([^"]*)"');
        final matches = exrateRegex.allMatches(xmlString);
        
        final commonCurrencies = ['USD', 'EUR', 'JPY', 'GBP', 'AUD', 'SGD', 'THB', 'CNY', 'KRW', 'CAD', 'CHF', 'HKD'];
        
        for (var match in matches) {
          final code = match.group(1) ?? '';
          final name = match.group(2)?.trim() ?? '';
          final buy = match.group(3) ?? '-';
          final transfer = match.group(4) ?? '-';
          final sell = match.group(5) ?? '-';
          
          if (commonCurrencies.contains(code)) {
            result.add({
              'code': code,
              'name': _getCurrencyNameVi(code, name),
              'buy': buy,
              'sell': sell,
              'transfer': transfer,
            });
          }
        }
        result.sort((a, b) {
          if (a['code'] == 'USD') return -1;
          if (b['code'] == 'USD') return 1;
          return 0;
        });
        return result;
      }
      debugPrint('Failed to fetch exchange rates: Status ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error fetching exchange rates from Vietcombank: $e');
      return [];
    }
  }

  String _getCurrencyNameVi(String code, String defaultName) {
    final names = {
      'USD': 'Đô la Mỹ',
      'EUR': 'Euro',
      'JPY': 'Yên Nhật',
      'GBP': 'Bảng Anh',
      'AUD': 'Đô la Úc',
      'SGD': 'Đô la Singapore',
      'THB': 'Bạt Thái Lan',
      'CNY': 'Nhân dân tệ',
      'KRW': 'Won Hàn Quốc',
      'CAD': 'Đô la Canada',
      'CHF': 'Franc Thụy Sĩ',
      'HKD': 'Đô la Hồng Kông',
    };
    return names[code] ?? defaultName;
  }

  Future<List<Map<String, String>>> getFuelPrices() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConstants.fuelPriceUrl),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var table = document.querySelector('table.table');
        if (table != null) {
          var rows = table.querySelectorAll('tr');
          final List<Map<String, String>> prices = [];
          
          for (var i = 2; i < rows.length; i++) {
            var cols = rows[i].querySelectorAll('td');
            if (cols.length >= 4) {
              final type = cols[1].text.trim();
              final price = cols[2].text.trim().replaceAll(' đ', '');
              final diff = cols[3].text.trim().replaceAll(' đ', '');

              prices.add({
                'type': type,
                'price': price,
                'diff': diff,
              });
            }
          }
          if (prices.isNotEmpty) return prices;
        }
      }
      debugPrint('Failed to fetch fuel prices: Status ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('Error fetching fuel prices from PVOIL: $e');
      return [];
    }
  }
}
