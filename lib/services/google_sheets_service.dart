import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service để đồng bộ dữ liệu Quỹ Phòng với Google Sheets
class GoogleSheetsService {
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  // Spreadsheet ID từ URL: https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit
  static const String SPREADSHEET_ID = '1nmLuLHnA1mNYmTqZ9WI6DrxgFctu7KlzlYwCiDuFfOA';
  static const String API_BASE_URL = 'https://sheets.googleapis.com/v4/spreadsheets';
  
  // Cache access token
  String? _accessToken;
  
  /// Lấy access token từ SharedPreferences hoặc yêu cầu user nhập
  Future<String?> getAccessToken() async {
    if (_accessToken != null) return _accessToken;
    
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('google_sheets_access_token');
    return _accessToken;
  }
  
  /// Lưu access token
  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_sheets_access_token', token);
  }
  
  /// Tìm hoặc tạo sheet theo tên project
  Future<String?> findOrCreateSheet(String projectName) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('No access token available');
      return null;
    }
    
    try {
      // Lấy danh sách sheets
      final response = await http.get(
        Uri.parse('$API_BASE_URL/$SPREADSHEET_ID?access_token=$token'),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Error getting sheets: ${response.statusCode} - ${response.body}');
        return null;
      }
      
      final data = json.decode(response.body);
      final sheets = data['sheets'] as List;
      
      // Tìm sheet có tên = projectName
      for (var sheet in sheets) {
        final properties = sheet['properties'];
        if (properties['title'] == projectName) {
          return properties['sheetId'].toString();
        }
      }
      
      // Nếu không tìm thấy, tạo sheet mới
      return await _createSheet(projectName, token);
    } catch (e) {
      debugPrint('Error finding/creating sheet: $e');
      return null;
    }
  }
  
  /// Tạo sheet mới
  Future<String?> _createSheet(String projectName, String token) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/$SPREADSHEET_ID:batchUpdate?access_token=$token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'requests': [
            {
              'addSheet': {
                'properties': {
                  'title': projectName,
                }
              }
            }
          ]
        }),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Error creating sheet: ${response.statusCode} - ${response.body}');
        return null;
      }
      
      final data = json.decode(response.body);
      final sheetId = data['replies'][0]['addSheet']['properties']['sheetId'].toString();
      debugPrint('Created new sheet: $projectName (ID: $sheetId)');
      return sheetId;
    } catch (e) {
      debugPrint('Error creating sheet: $e');
      return null;
    }
  }
  
  /// Cập nhật giá trị vào ô cụ thể
  Future<bool> updateCell(String sheetName, String cell, dynamic value) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('No access token available');
      return false;
    }
    
    try {
      // Format giá trị (nếu là số, không cần quotes)
      final valueStr = value is num ? value.toString() : '"$value"';
      
      final response = await http.put(
        Uri.parse('$API_BASE_URL/$SPREADSHEET_ID/values/$sheetName!$cell?access_token=$token&valueInputOption=USER_ENTERED'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'values': [[value]]
        }),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Error updating cell: ${response.statusCode} - ${response.body}');
        return false;
      }
      
      debugPrint('Updated $sheetName!$cell = $value');
      return true;
    } catch (e) {
      debugPrint('Error updating cell: $e');
      return false;
    }
  }
  
  /// Đọc giá trị từ ô
  Future<String?> readCell(String sheetName, String cell) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('No access token available');
      return null;
    }
    
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/$SPREADSHEET_ID/values/$sheetName!$cell?access_token=$token'),
      );
      
      if (response.statusCode != 200) {
        debugPrint('Error reading cell: ${response.statusCode} - ${response.body}');
        return null;
      }
      
      final data = json.decode(response.body);
      final values = data['values'] as List?;
      if (values == null || values.isEmpty) return null;
      
      return values[0][0]?.toString();
    } catch (e) {
      debugPrint('Error reading cell: $e');
      return null;
    }
  }
  
  /// Đồng bộ chi tiết dữ liệu project lên Google Sheets (Side-by-Side Layout)
  /// Cột A-B: Danh sách chi tiêu
  /// Cột D-E: Bảng tổng kết
  Future<bool> syncProjectDetails({
    required String projectName,
    required double totalIncome,
    required List<Map<String, dynamic>> expenses, // List of {name, amount}
  }) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('No access token available for sync');
      return false;
    }

    try {
      // 1. Tìm hoặc tạo sheet
      final sheetId = await findOrCreateSheet(projectName);
      if (sheetId == null) return false;

      // 2. Tính toán tổng chi và còn lại
      double totalExpense = 0;
      for (var expense in expenses) {
        totalExpense += (expense['amount'] as num).toDouble();
      }
      final balance = totalIncome - totalExpense;

      // 3. Chuẩn bị dữ liệu batch update
      final List<Map<String, dynamic>> requests = [];

      // A. Clear cột A & B (Expenses) từ hàng 2 trở đi để xóa dữ liệu cũ
      requests.add({
        'updateCells': {
          'range': {
            'sheetId': int.parse(sheetId),
            'startRowIndex': 1, // Row 2
            'startColumnIndex': 0, // Col A
            'endColumnIndex': 2, // Col C (exclusive) -> A & B
          },
          'fields': 'userEnteredValue' // Chỉ clear giá trị
        }
      });

      // B. Ghi danh sách chi tiêu mới vào cột A & B (bắt đầu từ A2)
      if (expenses.isNotEmpty) {
        final rows = expenses.map((e) {
          return {
            'values': [
              {
                'userEnteredValue': {'stringValue': e['name']},
                'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
              },
              {
                'userEnteredValue': {'numberValue': e['amount']},
                'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
              }
            ]
          };
        }).toList();

        requests.add({
          'updateCells': {
            'start': {
              'sheetId': int.parse(sheetId),
              'rowIndex': 1, // Row 2
              'columnIndex': 0, // Col A
            },
            'rows': rows,
            'fields': 'userEnteredValue,userEnteredFormat'
          }
        });
      }

      // C. Ghi Header và Summary vào cột D & E (bắt đầu từ D1)
      final summaryRows = [
        // Row 1: Header
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Mục'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true}}
            },
            {
              'userEnteredValue': {'stringValue': 'Giá trị'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true}}
            }
          ]
        },
        // Row 2: Tổng thu
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Tổng thu'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
            },
            {
              'userEnteredValue': {'numberValue': totalIncome},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
            }
          ]
        },
        // Row 3: Tổng chi
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Tổng chi'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
            },
            {
              'userEnteredValue': {'numberValue': totalExpense},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
            }
          ]
        },
        // Row 4: Còn lại
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Còn lại'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
            },
            {
              'userEnteredValue': {'numberValue': balance},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman'}}
            }
          ]
        },
      ];

      requests.add({
        'updateCells': {
          'start': {
            'sheetId': int.parse(sheetId),
            'rowIndex': 0, // Row 1
            'columnIndex': 3, // Col D
          },
          'rows': summaryRows,
          'fields': 'userEnteredValue,userEnteredFormat'
        }
      });

      // D. Ghi Header cho cột Expenses (A1-B1) nếu cần
      requests.add({
        'updateCells': {
          'start': {
            'sheetId': int.parse(sheetId),
            'rowIndex': 0, // Row 1
            'columnIndex': 0, // Col A
          },
          'rows': [
            {
              'values': [
                {
                  'userEnteredValue': {'stringValue': 'Tên khoản chi'},
                  'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true}}
                },
                {
                  'userEnteredValue': {'stringValue': 'Số tiền'},
                  'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true}}
                }
              ]
            }
          ],
          'fields': 'userEnteredValue,userEnteredFormat'
        }
      });

      // 4. Gửi Request Batch Update
      final response = await http.post(
        Uri.parse('$API_BASE_URL/$SPREADSHEET_ID:batchUpdate?access_token=$token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'requests': requests}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Synced detailed project $projectName to Google Sheets');
        return true;
      } else {
        debugPrint('Error syncing details: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error details sync: $e');
      return false;
    }
  }

  /// Xóa access token
  
  /// Xóa access token
  Future<void> clearAccessToken() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_sheets_access_token');
  }
}
