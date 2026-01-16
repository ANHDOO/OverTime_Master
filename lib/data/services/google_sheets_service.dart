import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service để đồng bộ dữ liệu Quỹ Phòng với Google Sheets
class GoogleSheetsService {
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  // Spreadsheet ID mặc định từ user (File: OverTime Master - Quỹ Dự Án)
  static const String DEFAULT_SPREADSHEET_ID = '1-TndqomHGzja-u8p0JIK9kvNXqCijR9uG0gdejw_yQI';
  String? _spreadsheetId;
  static const String API_BASE_URL = 'https://sheets.googleapis.com/v4/spreadsheets';
  static const String DRIVE_API_URL = 'https://www.googleapis.com/drive/v3/files';
  
  // Google Sign-In instance với scopes cho Sheets API
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/spreadsheets',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );
  
  // Cache access token
  String? _accessToken;
  
  // Google Sign-In account (for Plan A)
  GoogleSignInAccount? _currentUser;

  /// Lấy spreadsheet ID (ưu tiên ID được lưu, sau đó là mặc định, cuối cùng là tạo mới)
  Future<String?> getSpreadsheetId() async {
    if (_spreadsheetId != null && _spreadsheetId!.isNotEmpty) {
      return _spreadsheetId;
    }
    
    final prefs = await SharedPreferences.getInstance();
    _spreadsheetId = prefs.getString('google_sheets_spreadsheet_id');
    
    if (_spreadsheetId != null && _spreadsheetId!.isNotEmpty) {
      return _spreadsheetId;
    }
    
    // Nếu chưa có ID nào được lưu, sử dụng ID mặc định
    _spreadsheetId = DEFAULT_SPREADSHEET_ID;
    await prefs.setString('google_sheets_spreadsheet_id', DEFAULT_SPREADSHEET_ID);
    
    return _spreadsheetId;
  }

  /// Lưu Spreadsheet ID tùy chỉnh
  Future<void> saveCustomSpreadsheetId(String id) async {
    _spreadsheetId = id.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('google_sheets_spreadsheet_id', _spreadsheetId!);
    debugPrint('[GoogleSheets] Custom Spreadsheet ID saved: $_spreadsheetId');
  }



  String _formatCurrency(num value) {
    try {
      return '${NumberFormat.decimalPattern('vi_VN').format(value)} đ';
    } catch (_) {
      return '${value.toString()} đ';
    }
  }

  /// Lấy access token từ Google Sign-In
  Future<String?> getAccessToken() async {
    if (_accessToken != null) {
      return _accessToken;
    }

    // Try to get token from Google Sign-In silently
    final signInToken = await _getTokenFromGoogleSignIn(silently: true);
    if (signInToken != null) {
      _accessToken = signInToken;
      return signInToken;
    }

    return null;
  }

  /// Tự động refresh token bằng cách đăng nhập im lặng
  Future<bool> refreshAccessToken() async {
    _accessToken = null;
    final token = await getAccessToken();
    return token != null;
  }

  /// Đăng nhập Google và lấy token cho Sheets API
  Future<String?> signInWithGoogle() async {
    try {
      debugPrint('[GoogleSheets] Starting Google Sign-In...');
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSheets] User cancelled sign-in');
        return null;
      }
      
      _currentUser = account;
      final auth = await account.authentication;
      final token = auth.accessToken;
      
      if (token != null) {
        _accessToken = token;
        debugPrint('[GoogleSheets] Sign-in successful, token obtained');
        return token;
      }
      
      return null;
    } catch (e) {
      debugPrint('[GoogleSheets] Sign-in error: $e');
      return null;
    }
  }

  /// Lấy token từ Google Sign-In (silent = không hiện popup)
  Future<String?> _getTokenFromGoogleSignIn({bool silently = true}) async {
    try {
      GoogleSignInAccount? account;
      
      if (silently) {
        // Thử đăng nhập im lặng (nếu đã có session)
        account = await _googleSignIn.signInSilently();
      } else {
        account = await _googleSignIn.signIn();
      }
      
      if (account == null) return null;
      
      _currentUser = account;
      final auth = await account.authentication;
      final token = auth.accessToken;
      
      if (token != null) {
        _accessToken = token;
        debugPrint('[GoogleSheets] Got token from Google Sign-In');
        return token;
      }
      
      return null;
    } catch (e) {
      debugPrint('[GoogleSheets] Silent sign-in failed: $e');
      return null;
    }
  }

  /// Kiểm tra trạng thái đăng nhập Google
  Future<bool> isSignedInWithGoogle() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Đăng xuất Google
  Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _accessToken = null;
    debugPrint('[GoogleSheets] Signed out from Google');
  }

  /// Lấy email của user đã đăng nhập
  String? get currentUserEmail => _currentUser?.email;

  /// Xóa access token cache và preference
  Future<void> clearAccessToken() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('google_sheets_access_token');
  }
  
  /// Tìm hoặc tạo sheet theo tên project
  Future<String?> findOrCreateSheet(String projectName) async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('No access token available');
      return null;
    }
    
    // Lấy spreadsheet ID (tự động tạo nếu chưa có)
    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      debugPrint('Cannot get or create spreadsheet');
      return null;
    }
    
    try {
      // Lấy danh sách sheets
      final response = await http.get(
        Uri.parse('$API_BASE_URL/$spreadsheetId?access_token=$token'),
      );

      if (response.statusCode == 401) {
        debugPrint('Sheets API returned 401, attempting token refresh');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retryToken = await getAccessToken();
          if (retryToken != null) {
            final retryResp = await http.get(Uri.parse('$API_BASE_URL/$spreadsheetId?access_token=$retryToken'));
            if (retryResp.statusCode == 200) {
              final data = json.decode(retryResp.body);
              final sheets = data['sheets'] as List;
              for (var sheet in sheets) {
                final properties = sheet['properties'];
                if (properties['title'] == projectName) {
                  return properties['sheetId'].toString();
                }
              }
              return await _createSheet(projectName, retryToken, spreadsheetId);
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
      return await _createSheet(projectName, token, spreadsheetId);
    } catch (e) {
      debugPrint('Error finding/creating sheet: $e');
      return null;
    }
  }
  
  /// Tạo sheet mới
  Future<String?> _createSheet(String projectName, String token, String spreadsheetId) async {
    try {
      final response = await http.post(
        Uri.parse('$API_BASE_URL/$spreadsheetId:batchUpdate?access_token=$token'),
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

    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) return false;
    
    try {
      // Format giá trị (nếu là số, không cần quotes)
      
      final response = await http.put(
        Uri.parse('$API_BASE_URL/$spreadsheetId/values/$sheetName!$cell?access_token=$token&valueInputOption=USER_ENTERED'),
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
              Uri.parse('$API_BASE_URL/$spreadsheetId/values/$sheetName!$cell?access_token=$retryToken&valueInputOption=USER_ENTERED'),
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

    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$API_BASE_URL/$spreadsheetId/values/$sheetName!$cell?access_token=$token'),
      );

      if (response.statusCode == 401) {
        debugPrint('401 reading cell, attempting refresh');
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          final retryToken = await getAccessToken();
          if (retryToken != null) {
            final retryResp = await http.get(Uri.parse('$API_BASE_URL/$spreadsheetId/values/$sheetName!$cell?access_token=$retryToken'));
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

    final spreadsheetId = await getSpreadsheetId();
    if (spreadsheetId == null) {
      debugPrint('Cannot get spreadsheet ID for sync');
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
        Uri.parse('$API_BASE_URL/$spreadsheetId:batchUpdate?access_token=$token'),
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
              Uri.parse('$API_BASE_URL/$spreadsheetId:batchUpdate?access_token=$retryToken'),
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

}
