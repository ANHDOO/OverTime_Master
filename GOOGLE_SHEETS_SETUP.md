# Hướng dẫn Setup Google Sheets Integration

## Tổng quan

Tính năng này cho phép tự động đồng bộ dữ liệu Quỹ Phòng lên Google Sheets:
- **Tên dự án** (ví dụ: GT02) → **Tên sheet** trong Google Sheets
- **G31** = Tổng tiền nhận vào (income) của project
- **G32** = G31 - Tổng chi tiêu (expense) của project

## Cấu hình

### Bước 1: Setup Google Cloud Console

1. Vào [Google Cloud Console](https://console.cloud.google.com/)
2. Chọn project hiện có (hoặc tạo mới)
3. Bật **Google Sheets API** và **Google Drive API**
4. Tạo **OAuth 2.0 Client ID**:
   - Application type: **Desktop app**
   - Tải file `credentials.json`
   - Đặt vào thư mục `tool/credentials.json`

### Bước 2: Lấy Access Token

#### Cách 1: Dùng script Python (Khuyến nghị)

```bash
# Cài dependencies
pip install google-auth-oauthlib google-api-python-client

# Chạy script
python tool/get_google_sheets_token.py
```

Script sẽ:
1. Mở browser để đăng nhập Google
2. Yêu cầu quyền truy cập Google Sheets
3. Hiển thị Access Token
4. Copy token và dán vào app

#### Cách 2: Dùng Google OAuth Playground

1. Vào [Google OAuth Playground](https://developers.google.com/oauthplayground/)
2. Ở bên trái, tìm và chọn:
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/drive.file`
3. Click "Authorize APIs"
4. Đăng nhập và cho phép
5. Click "Exchange authorization code for tokens"
6. Copy **Access token** (token đầu tiên)

### Bước 3: Nhập Token vào App

1. Mở app → **Settings**
2. Scroll xuống phần **Đồng bộ Google Sheets**
3. Click **Cấu hình Google Sheets**
4. Dán Access Token vào
5. Click **Lưu**

## Cách hoạt động

### Tự động đồng bộ

Khi bạn:
- ✅ **Thêm transaction mới** → Tự động sync project đó lên Sheets
- ✅ **Sửa transaction** → Tự động sync lại
- ✅ **Xóa transaction** → Tự động sync lại

### Đồng bộ thủ công

1. Vào **Settings** > **Đồng bộ Google Sheets**
2. Click **Đồng bộ tất cả dự án**
3. App sẽ sync tất cả projects lên Google Sheets

## Cấu trúc trên Google Sheets

```
Spreadsheet: 1nmLuLHnA1mNYmTqZ9WI6DrxgFctu7KlzlYwCiDuFfOA
├── Sheet "GT02"
│   ├── G31: 10,000,000 (Tổng income)
│   └── G32: 9,655,000 (G31 - Tổng expense)
├── Sheet "GT03"
│   ├── G31: ...
│   └── G32: ...
└── ...
```

## Lưu ý

- ⚠️ Access Token có thời hạn (thường 1 giờ)
- 🔄 Nếu token hết hạn, cần lấy token mới
- 📝 Token được lưu trong app, không cần nhập lại mỗi lần mở app
- 🔐 Token chỉ có quyền đọc/ghi Sheets, không có quyền khác

## Troubleshooting

### Lỗi: "No access token available"
- Chưa nhập token → Vào Settings > Cấu hình Google Sheets

### Lỗi: "Error updating cell: 401"
- Token hết hạn → Lấy token mới và cập nhật lại

### Lỗi: "Error creating sheet: 403"
- Không có quyền tạo sheet → Kiểm tra quyền trong Google Cloud Console

### Sheet không được tạo tự động
- Kiểm tra token có quyền `spreadsheets` và `drive.file`
- Thử đồng bộ thủ công từ Settings

## Ví dụ

1. Thêm transaction:
   - Project: **GT02**
   - Type: **Thu vào**
   - Amount: **10,000,000**

2. App tự động:
   - Tìm hoặc tạo sheet tên "GT02"
   - Ghi **G31 = 10,000,000**
   - Tính **G32 = 10,000,000 - tổng chi tiêu**

3. Thêm chi tiêu:
   - Project: **GT02**
   - Type: **Chi ra**
   - Amount: **200,000**

4. App tự động:
   - Tính lại tổng expense
   - Cập nhật **G32 = 10,000,000 - 200,000 = 9,800,000**
