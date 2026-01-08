# 🔐 Hướng dẫn Setup Google Sign In cho OverTime App

## 🚨 Vấn đề hiện tại
App đang gặp lỗi **ApiException 10** khi đăng nhập Google, có nghĩa là chưa cấu hình đúng Google Sign In.

## ✅ Đã fix
- ✅ Đã thêm Google Services plugin vào `android/app/build.gradle.kts`
- ✅ Đã thêm Google Services classpath vào `android/build.gradle.kts`

## 🔧 Cần làm tiếp

### Bước 1: Tạo Firebase Project
1. Vào [Firebase Console](https://console.firebase.google.com/)
2. Click **"Create a project"** hoặc chọn project existing
3. Điền thông tin project

### Bước 2: Thêm Android App vào Firebase
1. Trong Firebase Console, click **"Add app"** → **Android icon**
2. **Android package name**: `com.anhdo.note_overtime.note_overtime`
3. **App nickname**: `OverTime App` (tùy chọn)
4. Click **"Register app"**

### Bước 3: Download google-services.json
1. Firebase sẽ generate file `google-services.json`
2. **Click "Download google-services.json"**
3. **Copy file vào thư mục `android/app/`** của project Flutter
4. **Đổi tên file thành `google-services.json`** (nếu chưa có)

```
android/app/google-services.json  ← Đặt file vào đây
```

**Hoặc edit file template có sẵn:**
- File `android/app/google-services-template.json` đã có sẵn
- Thay thế các giá trị YOUR_* bằng thông tin từ Firebase Console
- Đổi tên file thành `google-services.json`

### Bước 4: Lấy SHA-1 Fingerprint
#### Cách 1: Từ Keytool (recommended)
```bash
# Chạy command sau trong terminal (Windows)
keytool -list -v -keystore "C:\Users\Anh Do\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**SHA-1 fingerprint của bạn:**
```
F0:40:49:DE:04:CC:B4:69:09:88:EE:ED:C1:2C:5A:58:E9:12:5F:0B
```

#### Cách 2: Từ Gradle
```bash
# Trong thư mục android của project
./gradlew signingReport
```

### Bước 5: Thêm SHA-1 vào Firebase
1. Trong Firebase Console → Project Settings → General tab
2. Scroll xuống **"Your apps"** section
3. Click vào Android app (`com.anhdo.note_overtime.note_overtime`)
4. Trong **"SHA certificate fingerprints"** section:
   - Click **"Add fingerprint"**
   - Paste SHA-1 fingerprint: `F0:40:49:DE:04:CC:B4:69:09:88:EE:ED:C1:2C:5A:58:E9:12:5F:0B`
   - Click **"Save"**

### Bước 6: Enable Google Sign In trong Firebase
1. Trong Firebase Console → Authentication → Sign-in method
2. Tìm **"Google"** trong provider list
3. Click vào **Google**
4. Toggle **"Enable"**
5. Điền **"Project support email"** (email của bạn)
6. Click **"Save"**

### Bước 7: Test Google Sign In
1. Build lại app:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

2. Install APK lên device
3. Mở app → Settings → Sao lưu & Khôi phục
4. Click **"Đăng nhập Google"**
5. Nếu vẫn lỗi, check logcat để xem lỗi chi tiết

## 🔍 Troubleshooting

### Lỗi: "google-services.json not found"
- ✅ Đảm bảo file `google-services.json` ở đúng vị trí: `android/app/`
- ✅ File không được để trong thư mục con

### Lỗi: SHA-1 fingerprint
- ✅ Sử dụng SHA-1 từ debug keystore (không phải release)
- ✅ SHA-1 format: `AA:BB:CC:DD:EE:FF:GG:HH:II:JJ:KK:LL:MM:NN:OO:PP:QQ:RR:SS:TT`

### Lỗi: Package name
- ✅ Package name phải khớp chính xác: `com.anhdo.note_overtime.note_overtime`
- ✅ Check trong `android/app/build.gradle.kts` → `applicationId`

### Lỗi: Google Play Services
- ✅ Device phải có Google Play Services
- ✅ Test trên device thật, không phải emulator (nếu có thể)

## 📱 Test trên Device

### Chuẩn bị device:
1. Enable **"Unknown sources"** (Settings → Security)
2. Enable **Google Play Services**
3. Có tài khoản Google đã đăng nhập

### Steps test:
1. Build APK: `flutter build apk --release`
2. Transfer APK sang device
3. Install APK
4. Mở app → Settings → Backup
5. Click "Đăng nhập Google"
6. Chọn tài khoản Google
7. Nếu thành công: có thể sử dụng Google Drive backup

## 🎯 Kết quả mong đợi

Sau khi setup đúng:
- ✅ Google Sign In hoạt động bình thường
- ✅ Có thể backup/restore data lên Google Drive
- ✅ Sync với Google Sheets vẫn hoạt động
- ✅ Tất cả tính năng cloud hoạt động

## 📞 Hỗ trợ

Nếu vẫn gặp vấn đề:
1. Check logcat: `adb logcat | grep -i google`
2. Verify SHA-1: `./gradlew signingReport`
3. Check Firebase Console settings
4. Ensure google-services.json is valid JSON

---

**⚠️ Quan trọng**: Không commit file `google-services.json` lên Git (đã có trong .gitignore)
