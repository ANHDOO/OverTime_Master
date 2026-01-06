# 🚀 Hướng dẫn Deploy và Auto Update cho OverTime App

## Tổng quan

Hệ thống này cho phép:
1. ✅ Tự động build APK và upload lên Google Drive theo version
2. ✅ Tự động tạo README và metadata.json cho mỗi version
3. ✅ App tự động kiểm tra và tải bản cập nhật mới

## 📋 Yêu cầu

### 1. Python Environment
```bash
pip install pyyaml google-auth-oauthlib google-api-python-client
```

### 2. Google Drive API Setup
1. Vào [Google Cloud Console](https://console.cloud.google.com/)
2. Chọn project hiện có (hoặc tạo mới)
3. Bật **Google Drive API**
4. Tạo **OAuth 2.0 Client ID**:
   - Application type: **Desktop app**
   - Tải file `credentials.json`
   - Đặt vào thư mục `tool/credentials.json`

### 3. Flutter Dependencies
Đã được thêm vào `pubspec.yaml`:
- `package_info_plus: ^8.0.0`
- `http: ^1.2.2`
- `open_file: ^3.3.2`

## 🔧 Cấu hình

### 1. Google Drive Folder
- Folder ID hiện tại: `1NjHCrZyZohQnRptgZL62G7LUTEFL66YY`
- Nếu muốn thay đổi, sửa `DRIVE_PARENT_FOLDER_ID` trong `tool/deploy_overtime.py`

### 2. Release Notes
Tạo file `release_notes/<version>.md` để mô tả thay đổi cho mỗi version:
```
release_notes/
  ├── 1.0.2.md
  ├── 1.0.3.md
  └── ...
```

Nếu không có file release notes, script sẽ tạo README mặc định.

## 📦 Deploy APK

### Cách 1: Tự động (Build + Deploy)
```bash
python tool/deploy_overtime.py
```

### Cách 2: Build thủ công rồi Deploy
```bash
# Build APK
flutter clean
flutter build apk --release

# Deploy
python tool/deploy_overtime.py
```

### Quy trình Deploy
1. ✅ Đọc version từ `pubspec.yaml` (ví dụ: `1.0.2+3`)
2. ✅ Build APK nếu chưa có
3. ✅ Tạo thư mục `1.0.2` trên Google Drive
4. ✅ Upload các file:
   - `overtime_1.0.2.apk`
   - `README.md` (từ release_notes hoặc template)
   - `metadata.json` (thông tin version, download URL)
5. ✅ Upload `latest_metadata.json` vào root folder
6. ✅ Đặt quyền public cho tất cả files

## 📱 Cấu trúc trên Google Drive

```
OverTimeApp/ (Folder ID: 1NjHCrZyZohQnRptgZL62G7LUTEFL66YY)
├── latest_metadata.json  ← App check file này để biết version mới nhất
└── 1.0.2/
    ├── overtime_1.0.2.apk
    ├── README.md
    └── metadata.json
└── 1.0.3/
    ├── overtime_1.0.3.apk
    ├── README.md
    └── metadata.json
```

## 🔄 Cập nhật METADATA_URL trong App

Sau khi deploy lần đầu tiên:

1. **Lấy File ID của `latest_metadata.json`**:
   - Vào Google Drive
   - Click vào file `latest_metadata.json`
   - Copy File ID từ URL (phần sau `/file/d/`)

2. **Cập nhật trong code**:
   - Mở `lib/services/update_service.dart`
   - Tìm dòng:
     ```dart
     static const String METADATA_URL = 
         'https://drive.google.com/uc?export=download&id=YOUR_METADATA_FILE_ID';
     ```
   - Thay `YOUR_METADATA_FILE_ID` bằng File ID thực tế

## 📲 Tính năng Auto Update trong App

### 1. Tự động kiểm tra khi khởi động
- App tự động check update khi mở (trong `SplashScreen`)
- Nếu có bản mới, hiển thị dialog hỏi người dùng

### 2. Kiểm tra thủ công
- Vào **Settings** > **Thông tin ứng dụng**
- Click **Kiểm tra cập nhật**

### 3. Quy trình cài đặt
1. App tải APK về thư mục tạm
2. Mở file APK để cài đặt
3. Android sẽ tự động xử lý quyền cài đặt

## 🔐 Quyền Android

Đã được thêm vào `AndroidManifest.xml`:
- `REQUEST_INSTALL_PACKAGES` - Cho phép cài đặt APK
- `INTERNET` - Tải file từ Drive

## 📝 Release Notes Template

Tạo file `release_notes/<version>.md`:

```markdown
# OverTime v1.0.3

## 📱 Thông tin phiên bản
- **Version:** 1.0.3
- **Build:** 4
- **Ngày phát hành:** 07/01/2026

## ✨ Tính năng mới
- Tính năng A
- Tính năng B

## 🐛 Sửa lỗi
- Sửa lỗi X
- Sửa lỗi Y

## 📥 Hướng dẫn cài đặt
1. Tải file APK về thiết bị Android
2. Cho phép cài đặt từ nguồn không xác định trong Settings
3. Mở file APK và cài đặt
```

## 🐛 Troubleshooting

### Lỗi: "Không tìm thấy credentials.json"
- Đảm bảo file `tool/credentials.json` tồn tại
- Tải từ Google Cloud Console nếu chưa có

### Lỗi: "Token expired"
- Xóa file `tool/token.pickle`
- Chạy lại script để đăng nhập lại

### App không tải được update
- Kiểm tra `METADATA_URL` đã đúng File ID chưa
- Kiểm tra file `latest_metadata.json` có quyền public không
- Kiểm tra kết nối internet

### Không thể cài đặt APK
- Vào Settings > Apps > Special app access > Install unknown apps
- Cho phép ứng dụng này cài đặt APK

## 📚 Files liên quan

- `tool/deploy_overtime.py` - Script deploy
- `lib/services/update_service.dart` - Service check update
- `lib/screens/splash_screen.dart` - Tích hợp auto check
- `lib/screens/settings_screen.dart` - Nút check thủ công
- `release_notes/` - Thư mục chứa release notes

## ✅ Checklist trước khi deploy

- [ ] Đã cập nhật version trong `pubspec.yaml`
- [ ] Đã tạo file `release_notes/<version>.md` (nếu có thay đổi)
- [ ] Đã có `tool/credentials.json`
- [ ] Đã test build APK thành công
- [ ] Sau khi deploy, cập nhật `METADATA_URL` trong `update_service.dart`

## 🎉 Hoàn thành!

Sau khi setup xong, bạn chỉ cần:
1. Cập nhật version trong `pubspec.yaml`
2. Chạy `python tool/deploy_overtime.py`
3. App sẽ tự động phát hiện và cài đặt bản mới!
