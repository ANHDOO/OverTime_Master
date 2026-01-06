# Hướng dẫn Build và Deploy APK lên Google Drive

## Yêu cầu

1. **Python 3.7+** đã cài đặt
2. **Flutter SDK** đã cài đặt và cấu hình
3. **Google Drive API Credentials**:
   - Vào [Google Cloud Console](https://console.cloud.google.com/)
   - Tạo project hoặc chọn project hiện có
   - Bật Google Drive API
   - Tạo OAuth 2.0 credentials (Application type: Desktop app)
   - Tải file `credentials.json` và đặt vào thư mục `tool/`

## Cài đặt Python dependencies

```bash
pip install pyyaml google-auth-oauthlib google-api-python-client
```

## Cấu hình

1. **Đặt credentials.json vào thư mục `tool/`**:
   ```
   tool/
     ├── credentials.json  (file này bạn tải từ Google Cloud Console)
     ├── deploy_overtime.py
     └── README.md
   ```

2. **Folder ID trên Google Drive**:
   - Script đã được cấu hình với folder ID: `1NjHCrZyZohQnRptgZL62G7LUTEFL66YY`
   - Nếu muốn thay đổi, sửa biến `DRIVE_PARENT_FOLDER_ID` trong `deploy_overtime.py`

## Sử dụng

### Cách 1: Build và Deploy tự động

```bash
python tool/deploy_overtime.py
```

Script sẽ:
1. Đọc version từ `pubspec.yaml`
2. Build APK release (nếu chưa có)
3. Tạo thư mục version trên Google Drive
4. Upload APK, README.md và metadata.json
5. Đặt quyền public cho tất cả files

### Cách 2: Build thủ công rồi Deploy

```bash
# Build APK
flutter clean
flutter build apk --release

# Deploy
python tool/deploy_overtime.py
```

## Cấu trúc trên Google Drive

Sau khi deploy, cấu trúc trên Drive sẽ như sau:

```
OverTimeApp/ (Folder ID: 1NjHCrZyZohQnRptgZL62G7LUTEFL66YY)
├── latest_metadata.json  (file này app sẽ check để biết version mới nhất)
└── 1.0.2/  (thư mục theo version)
    ├── overtime_1.0.2.apk
    ├── README.md
    └── metadata.json
└── 1.0.3/  (version tiếp theo)
    ├── overtime_1.0.3.apk
    ├── README.md
    └── metadata.json
```

## Release Notes

Để thêm release notes cho mỗi version:

1. Tạo file `release_notes/<version>.md` (ví dụ: `release_notes/1.0.3.md`)
2. Viết nội dung changelog vào file đó
3. Script sẽ tự động đọc và sử dụng khi deploy

Nếu không có file release notes, script sẽ tạo README mặc định.

## Cập nhật METADATA_URL trong app

Sau khi deploy lần đầu, bạn cần:

1. Lấy File ID của `latest_metadata.json` trên Drive
2. Cập nhật `METADATA_URL` trong `lib/services/update_service.dart`:

```dart
static const String METADATA_URL = 
    'https://drive.google.com/uc?export=download&id=YOUR_METADATA_FILE_ID';
```

Thay `YOUR_METADATA_FILE_ID` bằng File ID thực tế.

## Lưu ý

- Lần đầu chạy script sẽ mở browser để xác thực OAuth
- Token sẽ được lưu vào `tool/token.pickle` để dùng lại
- Nếu token hết hạn, script sẽ tự động refresh hoặc yêu cầu đăng nhập lại
- Tất cả files được upload sẽ có quyền public để app có thể tải về
