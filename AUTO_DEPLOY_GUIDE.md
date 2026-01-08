# 🚀 Hướng dẫn Deploy App Hoàn Toàn Tự Động

## 📋 Tổng quan

Hệ thống deploy của **OverTime App** đã được tối ưu để **hoàn toàn tự động**. Bạn chỉ cần:

1. **Setup 1 lần** (5 phút)
2. **Double-click để deploy** mọi lần sau

## 🛠️ Setup (5 phút)

### Bước 1: Cài đặt Python Dependencies
```bash
pip install pyyaml google-auth-oauthlib google-api-python-client
```

### Bước 2: Setup Google Drive API

1. **Tạo Google Cloud Project**:
   - Vào [Google Cloud Console](https://console.cloud.google.com/)
   - Tạo project mới: `OverTimeApp`

2. **Bật Google Drive API**:
   - **APIs & Services** → **Library**
   - Tìm "Google Drive API" → **Enable**

3. **Tạo OAuth Credentials**:
   - **APIs & Services** → **Credentials**
   - **Create Credentials** → **OAuth client ID**
   - **Application type**: **Desktop app**
   - **Name**: `OverTime Desktop Client`
   - **Download** file JSON

4. **Đặt file credentials**:
   - Đổi tên file JSON thành `credentials.json`
   - Copy vào thư mục `tool/credentials.json`

## 🚀 Deploy App

### Cách 1: Double-click (Dễ nhất)
```bash
# Double-click file: deploy.bat
```

### Cách 2: Command Line
```bash
python tool/deploy_overtime.py
```

### Cách 3: Chỉ build APK
```bash
flutter clean
flutter build apk --release
```

## 📱 Kết quả sau deploy

### Google Drive Structure:
```
📁 OverTimeApp/
├── 📄 latest_metadata.json     ← App check file này
├── 📁 1.0.7/
├── 📁 1.1.8/
│   ├── 📱 overtime_1.1.8.apk   ← APK để download
│   ├── 📄 README.md            ← Release notes
│   └── 📄 metadata.json        ← Version info
└── 📁 ...
```

### App Behavior:
- ✅ **Tự động check update** khi app khởi động
- ✅ **Thông báo phiên bản mới** cho người dùng
- ✅ **Download trực tiếp** trong app
- ✅ **Không cần làm gì thêm!**

## 🔧 Scripts có sẵn

| File | Chức năng |
|------|-----------|
| `deploy.bat` | 🚀 Deploy hoàn toàn tự động (double-click) |
| `tool/deploy_overtime.py` | 🔨 Build + Upload Google Drive |
| `tool/get_metadata_file_id.py` | 🔍 Kiểm tra File ID metadata |

## 📋 Workflow

### Lần đầu (Setup):
1. Setup Google Cloud API
2. Đặt `credentials.json`
3. Chạy `deploy.bat` (sẽ mở browser để login)
4. ✅ Hoàn thành!

### Các lần sau:
1. **Thay đổi code app**
2. **Double-click `deploy.bat`**
3. ✅ **App đã được update tự động!**

## 🚨 Troubleshooting

### ❌ "Không tìm thấy credentials.json"
```
Giải pháp:
1. Kiểm tra file credentials.json có trong tool/
2. Download lại từ Google Cloud Console nếu cần
```

### ❌ "APK build failed"
```
Giải pháp:
1. flutter clean
2. flutter pub get
3. flutter doctor
4. Chạy lại deploy
```

### ❌ "Upload failed"
```
Giải pháp:
1. Kiểm tra internet
2. Token có thể hết hạn, chạy lại sẽ refresh
3. Kiểm tra quyền Google Drive
```

### ❌ "App không check được update"
```
Giải pháp:
1. Kiểm tra latest_metadata.json trên Drive
2. File phải được share public
3. File ID trong code đã được cập nhật
```

## 📈 Version Management

### Cập nhật version:
```yaml
# pubspec.yaml
version: 1.1.8+3  # Tăng version + build number
```

### Release notes:
```
release_notes/1.1.8.md  # Tạo file này cho mỗi version
```

## 🎯 Kết luận

**Với hệ thống này, việc deploy app trở nên hoàn toàn tự động!**

- ⏱️ **Thời gian deploy**: 2-3 phút
- 🤖 **Độ tự động**: 100%
- 📱 **User experience**: Tự động update trong app
- 🔄 **Maintenance**: Chỉ cần double-click

**Chúc mừng! App của bạn giờ đây có hệ thống deploy professional! 🚀**
