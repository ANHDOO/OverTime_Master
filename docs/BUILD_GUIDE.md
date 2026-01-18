# Hướng dẫn Build ứng dụng OverTime

> **Phiên bản tài liệu:** 1.0  
> **Cập nhật:** 17/01/2026  
> **Áp dụng cho:** OverTime v1.4.7+

---

## 📋 Mục lục

1. [Yêu cầu môi trường](#yêu-cầu-môi-trường)
2. [Cài đặt ban đầu](#cài-đặt-ban-đầu)
3. [Quy trình Build](#quy-trình-build)
4. [Deploy lên GitHub Releases](#deploy-lên-github-releases)
5. [Xử lý lỗi thường gặp](#xử-lý-lỗi-thường-gặp)
6. [Cấu hình quan trọng](#cấu-hình-quan-trọng)

---

## Yêu cầu môi trường

### Phần mềm bắt buộc

| Thành phần | Phiên bản tối thiểu | Ghi chú |
|------------|---------------------|---------|
| **Flutter SDK** | 3.10.3 | Kiểm tra: `flutter --version` |
| **Java JDK** | 17 | Bắt buộc JDK 17, không phải JDK 8 |
| **Android SDK** | API 35 | compileSdk trong `build.gradle` |
| **Python** | 3.8+ | Để chạy script deploy |
| **Git** | 2.0+ | Để clone/push code |

### Phiên bản Gradle (tự động download)

| Thành phần | Phiên bản |
|------------|-----------|
| **Gradle Wrapper** | 8.11.1 |
| **Android Gradle Plugin (AGP)** | 8.9.1 |
| **Kotlin** | 2.1.0 |

> ⚠️ **Lưu ý:** Gradle sẽ tự động download lần đầu build (~200MB). Cần kết nối internet ổn định.

---

## Cài đặt ban đầu

### Bước 1: Clone repository

```powershell
git clone https://github.com/ANHDOO/OverTime_Master.git
cd OverTime_Master
```

### Bước 2: Kiểm tra môi trường Flutter

```powershell
flutter doctor -v
```

Đảm bảo tất cả các mục đều có dấu ✓ (đặc biệt là Android toolchain).

### Bước 3: Cài đặt dependencies

```powershell
flutter pub get
```

### Bước 4: Kiểm tra các file cần thiết

Các file sau **PHẢI TỒN TẠI** để build thành công:

```
android/
├── app/
│   ├── google-services.json    ← Firebase config (bắt buộc)
│   └── src/main/
├── key.properties              ← Keystore config (bắt buộc cho release)
└── key.jks                     ← Keystore file (bắt buộc cho release)
```

> 🔒 **Bảo mật:** Các file `key.properties`, `key.jks`, và `google-services.json` KHÔNG được commit lên git. Liên hệ project owner để lấy các file này.

---

## Quy trình Build

### Build Debug APK

```powershell
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

### Build Release APK

```powershell
flutter build apk --release --target-platform android-arm64
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Kiểm tra lỗi trước khi build

```powershell
flutter analyze
```

- **0 errors:** OK để build
- **Warnings/Infos:** Có thể bỏ qua

---

## Deploy lên GitHub Releases

### Sử dụng script tự động

```powershell
# 1. Kiểm tra code (không build)
python tool/deploy_overtime.py --check

# 2. Build và deploy full
python tool/deploy_overtime.py
```

### Quy trình deploy thủ công

1. **Cập nhật version** trong `pubspec.yaml`:
   ```yaml
   version: 1.4.8+66  # format: major.minor.patch+buildNumber
   ```

2. **Tạo release notes** tại `release_notes/1.4.8.md`

3. **Build APK:**
   ```powershell
   flutter build apk --release --target-platform android-arm64
   ```

4. **Upload lên GitHub Releases**

---

## Xử lý lỗi thường gặp

### Lỗi 1: Gradle download timeout

**Triệu chứng:**
```
Exception in thread "main" java.net.SocketTimeoutException
```

**Giải pháp:**
- Kiểm tra kết nối internet
- Thử lại sau vài phút
- Hoặc download Gradle thủ công vào `~/.gradle/wrapper/dists/`

---

### Lỗi 2: AAR metadata version mismatch

**Triệu chứng:**
```
2 issues were found when checking AAR metadata:
Dependency 'androidx.activity:activity:1.11.0' requires Android Gradle plugin 8.9.1 or higher.
```

**Giải pháp:**
Cập nhật các file sau với version đúng:

`android/build.gradle.kts`:
```kotlin
classpath("com.android.tools.build:gradle:8.9.1")
```

`android/settings.gradle.kts`:
```kotlin
id("com.android.application") version "8.9.1" apply false
```

`android/gradle/wrapper/gradle-wrapper.properties`:
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip
```

---

### Lỗi 3: Java version không tương thích

**Triệu chứng:**
```
Unsupported class file major version 65
```

**Giải pháp:**
- Cài đặt JDK 17
- Set JAVA_HOME:
  ```powershell
  $env:JAVA_HOME = "C:\Program Files\Java\jdk-17"
  ```

---

### Lỗi 4: Keystore not found

**Triệu chứng:**
```
Could not read key from keystore
```

**Giải pháp:**
1. Đảm bảo file `android/key.jks` tồn tại
2. Kiểm tra `android/key.properties`:
   ```properties
   storePassword=your_store_password
   keyPassword=your_key_password
   keyAlias=your_key_alias
   storeFile=../key.jks
   ```

---

### Lỗi 5: Clean build

Khi gặp lỗi không xác định, thử clean toàn bộ:

```powershell
# Clean Flutter
flutter clean

# Clean Gradle cache
cd android
./gradlew clean
cd ..

# Rebuild
flutter pub get
flutter build apk --release
```

---

## Cấu hình quan trọng

### File: `pubspec.yaml`

```yaml
version: 1.4.7+65  # Luôn tăng buildNumber (+65) khi deploy
```

### File: `android/app/build.gradle.kts`

```kotlin
android {
    compileSdk = 35
    
    defaultConfig {
        minSdk = 24
        targetSdk = 35
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
```

### File: `android/gradle/wrapper/gradle-wrapper.properties`

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.11.1-all.zip
```

---

## 📞 Liên hệ hỗ trợ

Nếu gặp vấn đề không giải quyết được:
1. Kiểm tra Issues trên GitHub repository
2. Liên hệ project owner

---

*Tài liệu này được tạo tự động và cập nhật theo phiên bản mới nhất của dự án.*
