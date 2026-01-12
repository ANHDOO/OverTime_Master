import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

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
  DateTime? _accessTokenExpiry;
  String? _refreshToken;
  String? _clientId;
  String? _clientSecret;

  String _formatCurrency(num value) {
    try {
      return '${NumberFormat.decimalPattern('vi_VN').format(value)} đ';
    } catch (_) {
      return '${value.toString()} đ';
    }
  }

  /// Lấy access token từ SharedPreferences hoặc tự động refresh nếu cần
  Future<String?> getAccessToken() async {
    if (_accessToken != null) {
      // if we have expiry, ensure it's not about to expire
      if (_accessTokenExpiry != null) {
        final now = DateTime.now().toUtc();
        if (_accessTokenExpiry!.isAfter(now.add(const Duration(seconds: 60)))) {
          return _accessToken;
        }
      } else {
        return _accessToken;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('google_sheets_access_token');
    final expiryStr = prefs.getString('google_sheets_token_expiry');
    if (expiryStr != null) {
      try {
        _accessTokenExpiry = DateTime.parse(expiryStr).toUtc();
      } catch (_) {}
    }
    _refreshToken = prefs.getString('google_sheets_refresh_token');
    _clientId = prefs.getString('google_sheets_client_id');
    _clientSecret = prefs.getString('google_sheets_client_secret');

    // If token exists and not expired
    if (_accessToken != null && _accessTokenExpiry != null) {
      final now = DateTime.now().toUtc();
      if (_accessTokenExpiry!.isAfter(now.add(const Duration(seconds: 60)))) {
        return _accessToken;
      }
    }

    // Try to refresh
    if (_refreshToken != null) {
      final ok = await refreshAccessToken();
      if (ok) return _accessToken;
    }

    return _accessToken;
  }

  /// Lưu access token
  Future<void> setAccessToken(String token, {int? expiresInSeconds}) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_sheets_access_token', token);
    if (expiresInSeconds != null) {
      final expiry = DateTime.now().toUtc().add(Duration(seconds: expiresInSeconds));
      _accessTokenExpiry = expiry;
      await prefs.setString('google_sheets_token_expiry', expiry.toIso8601String());
    } else {
      await prefs.remove('google_sheets_token_expiry');
    }
  }

  Future<void> setRefreshToken(String refreshToken) async {
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_sheets_refresh_token', refreshToken);
  }

  Future<void> setClientId(String clientId) async {
    _clientId = clientId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_sheets_client_id', clientId);
  }

  Future<void> setClientSecret(String clientSecret) async {
    _clientSecret = clientSecret;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_sheets_client_secret', clientSecret);
  }

  /// Refresh access token using stored refresh token
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) {
      debugPrint('No refresh token available');
      return false;
    }
    try {
      final body = <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': _refreshToken!,
      };
      if (_clientId != null && _clientId!.isNotEmpty) {
        body['client_id'] = _clientId!;
      }
      if (_clientSecret != null && _clientSecret!.isNotEmpty) {
        body['client_secret'] = _clientSecret!;
      }
      final resp = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
      if (resp.statusCode != 200) {
        debugPrint('Refresh failed: ${resp.statusCode} - ${resp.body}');
        return false;
      }
      final data = json.decode(resp.body);
      final access = data['access_token'] as String?;
      final expiresIn = (data['expires_in'] as num?)?.toInt();
      final newRefresh = data['refresh_token'] as String?;
      if (access == null) return false;
      await setAccessToken(access, expiresInSeconds: expiresIn ?? 3600);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await setRefreshToken(newRefresh);
      }
      debugPrint('Access token refreshed');
      return true;
    } catch (e) {
      debugPrint('Error refreshing token: $e');
      return false;
    }
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

      if (response.statusCode == 401) {
        debugPrint('Sheets API returned 401, attempting token refresh');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retryToken = await getAccessToken();
          if (retryToken != null) {
            final retryResp = await http.get(Uri.parse('$API_BASE_URL/$SPREADSHEET_ID?access_token=$retryToken'));
            if (retryResp.statusCode == 200) {
              final data = json.decode(retryResp.body);
              final sheets = data['sheets'] as List;
              for (var sheet in sheets) {
                final properties = sheet['properties'];
                if (properties['title'] == projectName) {
                  return properties['sheetId'].toString();
                }
              }
              return await _createSheet(projectName, retryToken);
            } else {
              debugPrint('Retry failed: ${retryResp.statusCode} - ${retryResp.body}');
              return null;
            }
          }
        }
        debugPrint('Error getting sheets: ${response.statusCode} - ${response.body}');
        return null;
      }

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

      if (response.statusCode == 401) {
        debugPrint('401 updating cell, attempting refresh');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retryToken = await getAccessToken();
          if (retryToken != null) {
            final retryResp = await http.put(
              Uri.parse('$API_BASE_URL/$SPREADSHEET_ID/values/$sheetName!$cell?access_token=$retryToken&valueInputOption=USER_ENTERED'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'values': [[value]]}),
            );
            if (retryResp.statusCode != 200) {
              debugPrint('Error updating cell after refresh: ${retryResp.statusCode} - ${retryResp.body}');
              return false;
            }
          }
        } else {
          debugPrint('Refresh failed when updating cell: ${response.body}');
          return false;
        }
      } else if (response.statusCode != 200) {
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

      if (response.statusCode == 401) {
        debugPrint('401 reading cell, attempting refresh');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retryToken = await getAccessToken();
          if (retryToken != null) {
            final retryResp = await http.get(Uri.parse('$API_BASE_URL/$SPREADSHEET_ID/values/$sheetName!$cell?access_token=$retryToken'));
            if (retryResp.statusCode != 200) {
              debugPrint('Error reading cell after refresh: ${retryResp.statusCode} - ${retryResp.body}');
              return null;
            }
            final data = json.decode(retryResp.body);
            final values = data['values'] as List?;
            if (values == null || values.isEmpty) return null;
            return values[0][0]?.toString();
          }
        }
        debugPrint('Error reading cell: ${response.statusCode} - ${response.body}');
        return null;
      }

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

      // A. Clear cột A, B, C & D (Expenses + Notes) từ hàng 2 trở đi để xóa dữ liệu cũ
      requests.add({
        'updateCells': {
          'range': {
            'sheetId': int.parse(sheetId),
            'startRowIndex': 1, // Row 2
            'startColumnIndex': 0, // Col A
            'endColumnIndex': 4, // Col E (exclusive) -> A, B, C & D
          },
          'fields': 'userEnteredValue' // Chỉ clear giá trị
        }
      });

      // B. Ghi danh sách chi tiêu mới vào cột A, B, C & D (bắt đầu từ A2)
      if (expenses.isNotEmpty) {
        final rows = expenses.map((e) {
          final date = e['date'] as DateTime;
          final formattedDate = '${date.day}/${date.month}/${date.year}';
          final amount = e['amount'] as num;
          final formattedAmount = _formatCurrency(amount);
          final note = e['note'] ?? '';
          return {
            'values': [
              {
                'userEnteredValue': {'stringValue': e['name']},
                'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
              },
              {
                'userEnteredValue': {'stringValue': formattedAmount},
                'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
              },
              {
                'userEnteredValue': {'stringValue': formattedDate},
                'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
              },
              {
                'userEnteredValue': {'stringValue': note},
                'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
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
        
        // Thêm border cho vùng Expenses (A1:D{n})
        final int expenseCount = expenses.length;
        requests.add({
          'updateBorders': {
            'range': {
              'sheetId': int.parse(sheetId),
              'startRowIndex': 0,
              'endRowIndex': 1 + expenseCount, // header + items
              'startColumnIndex': 0,
              'endColumnIndex': 4
            },
            'top': {
              'style': 'SOLID',
              'color': {'red': 0, 'green': 0, 'blue': 0}
            },
            'bottom': {
              'style': 'SOLID',
              'color': {'red': 0, 'green': 0, 'blue': 0}
            },
            'left': {
              'style': 'SOLID',
              'color': {'red': 0, 'green': 0, 'blue': 0}
            },
            'right': {
              'style': 'SOLID',
              'color': {'red': 0, 'green': 0, 'blue': 0}
            },
            'innerHorizontal': {
              'style': 'SOLID',
              'color': {'red': 0, 'green': 0, 'blue': 0}
            },
            'innerVertical': {
              'style': 'SOLID',
              'color': {'red': 0, 'green': 0, 'blue': 0}
            }
          }
        });
      }

      // C. Ghi Header và Summary vào cột D & E (bắt đầu từ D1)
      // Chuyển Summary sang cột F & G để không đè lên cột Ghi chú (D)
      final summaryRows = [
        // Row 1: Header
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Mục'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}}
            },
            {
              'userEnteredValue': {'stringValue': 'Giá trị'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}}
            }
          ]
        },
        // Row 2: Tổng thu
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Tổng thu'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}}
            },
            {
              'userEnteredValue': {'stringValue': _formatCurrency(totalIncome)},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
            }
          ]
        },
        // Row 3: Tổng chi
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Tổng chi'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}}
            },
            {
              'userEnteredValue': {'stringValue': _formatCurrency(totalExpense)},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
            }
          ]
        },
        // Row 4: Còn lại
        {
          'values': [
            {
              'userEnteredValue': {'stringValue': 'Còn lại'},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}}
            },
            {
              'userEnteredValue': {'stringValue': _formatCurrency(balance)},
              'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'fontSize': 16}}
            }
          ]
        },
      ];

      requests.add({
        'updateCells': {
          'start': {
            'sheetId': int.parse(sheetId),
            'rowIndex': 0, // Row 1
            'columnIndex': 5, // Col F
          },
          'rows': summaryRows,
          'fields': 'userEnteredValue,userEnteredFormat'
        }
      });

      // D. Ghi Header cho cột Expenses (A1-D1) nếu cần
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
                  'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}, 'horizontalAlignment': 'CENTER', 'verticalAlignment': 'MIDDLE'}
                },
                {
                  'userEnteredValue': {'stringValue': 'Số tiền'},
                  'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}, 'horizontalAlignment': 'CENTER', 'verticalAlignment': 'MIDDLE'}
                },
                {
                  'userEnteredValue': {'stringValue': 'Ngày chi'},
                  'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}, 'horizontalAlignment': 'CENTER', 'verticalAlignment': 'MIDDLE'}
                },
                {
                  'userEnteredValue': {'stringValue': 'Ghi chú'},
                  'userEnteredFormat': {'textFormat': {'fontFamily': 'Times New Roman', 'bold': true, 'fontSize': 16}, 'horizontalAlignment': 'CENTER', 'verticalAlignment': 'MIDDLE'}
                }
              ]
            }
          ],
          'fields': 'userEnteredValue,userEnteredFormat'
        }
      });

      // Thêm border cho vùng Summary (F1:G4)
      requests.add({
        'updateBorders': {
          'range': {
            'sheetId': int.parse(sheetId),
            'startRowIndex': 0,
            'endRowIndex': 4,
            'startColumnIndex': 5,
            'endColumnIndex': 7
          },
          'top': {
            'style': 'SOLID',
            'color': {'red': 0, 'green': 0, 'blue': 0}
          },
          'bottom': {
            'style': 'SOLID',
            'color': {'red': 0, 'green': 0, 'blue': 0}
          },
          'left': {
            'style': 'SOLID',
            'color': {'red': 0, 'green': 0, 'blue': 0}
          },
          'right': {
            'style': 'SOLID',
            'color': {'red': 0, 'green': 0, 'blue': 0}
          },
          'innerHorizontal': {
            'style': 'SOLID',
            'color': {'red': 0, 'green': 0, 'blue': 0}
          },
          'innerVertical': {
            'style': 'SOLID',
            'color': {'red': 0, 'green': 0, 'blue': 0}
          }
        }
      });

      // 4. Gửi Request Batch Update
      var response = await http.post(
        Uri.parse('$API_BASE_URL/$SPREADSHEET_ID:batchUpdate?access_token=$token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'requests': requests}),
      );

      if (response.statusCode == 401) {
        debugPrint('401 batchUpdate, attempting token refresh');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retryToken = await getAccessToken();
          if (retryToken != null) {
            response = await http.post(
              Uri.parse('$API_BASE_URL/$SPREADSHEET_ID:batchUpdate?access_token=$retryToken'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'requests': requests}),
            );
          }
        }
      }

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

  /// Encrypt data using simple XOR (for demo - use AES in production)
  String _encryptData(String data) {
    const key = 'NoteOverTimeSheetsKey2024'; // Should be more secure in production
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final encrypted = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      encrypted.add(dataBytes[i] ^ keyBytes[i % keyBytes.length]);
    }

    return base64.encode(encrypted);
  }

  /// Decrypt data using simple XOR
  String _decryptData(String encryptedData) {
    try {
      const key = 'NoteOverTimeSheetsKey2024';
      final keyBytes = utf8.encode(key);
      final encryptedBytes = base64.decode(encryptedData);
      final decrypted = <int>[];

      for (int i = 0; i < encryptedBytes.length; i++) {
        decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }

      return utf8.decode(decrypted);
    } catch (e) {
      debugPrint('Error decrypting data: $e');
      return '';
    }
  }

  /// Export Google Sheets keys to encrypted JSON string
  Future<String?> exportKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final keys = {
        'access_token': prefs.getString('google_sheets_access_token') ?? '',
        'refresh_token': prefs.getString('google_sheets_refresh_token') ?? '',
        'client_id': prefs.getString('google_sheets_client_id') ?? '',
        'client_secret': prefs.getString('google_sheets_client_secret') ?? '',
        'token_expiry': prefs.getString('google_sheets_token_expiry') ?? '',
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      // Check if we have any keys to export
      final hasKeys = keys.values.any((value) => value.isNotEmpty);
      if (!hasKeys) {
        return null; // No keys to export
      }

      final jsonString = json.encode(keys);
      return _encryptData(jsonString);
    } catch (e) {
      debugPrint('Error exporting keys: $e');
      return null;
    }
  }

  /// Import Google Sheets keys from encrypted JSON string
  Future<bool> importKeys(String encryptedKeys) async {
    try {
      final decryptedJson = _decryptData(encryptedKeys);
      if (decryptedJson.isEmpty) {
        return false;
      }

      final keys = json.decode(decryptedJson) as Map<String, dynamic>;

      // Validate version
      final version = keys['version'] as String?;
      if (version != '1.0') {
        debugPrint('Unsupported key version: $version');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();

      // Import keys
      if (keys['access_token']?.isNotEmpty == true) {
        await prefs.setString('google_sheets_access_token', keys['access_token']);
        _accessToken = keys['access_token'];
      }

      if (keys['refresh_token']?.isNotEmpty == true) {
        await prefs.setString('google_sheets_refresh_token', keys['refresh_token']);
        _refreshToken = keys['refresh_token'];
      }

      if (keys['client_id']?.isNotEmpty == true) {
        await prefs.setString('google_sheets_client_id', keys['client_id']);
        _clientId = keys['client_id'];
      }

      if (keys['client_secret']?.isNotEmpty == true) {
        await prefs.setString('google_sheets_client_secret', keys['client_secret']);
        _clientSecret = keys['client_secret'];
      }

      if (keys['token_expiry']?.isNotEmpty == true) {
        await prefs.setString('google_sheets_token_expiry', keys['token_expiry']);
        try {
          _accessTokenExpiry = DateTime.parse(keys['token_expiry']);
        } catch (e) {
          debugPrint('Error parsing token expiry: $e');
        }
      }

      debugPrint('Successfully imported Google Sheets keys');
      return true;
    } catch (e) {
      debugPrint('Error importing keys: $e');
      return false;
    }
  }

  /// Check if Google Sheets keys are configured
  Future<bool> hasKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('google_sheets_access_token');
      final refreshToken = prefs.getString('google_sheets_refresh_token');
      final clientId = prefs.getString('google_sheets_client_id');

      return (accessToken?.isNotEmpty == true) ||
             (refreshToken?.isNotEmpty == true) ||
             (clientId?.isNotEmpty == true);
    } catch (e) {
      return false;
    }
  }
}
