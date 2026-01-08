# Hướng dẫn chạy app trên Android Emulator

## Vấn đề
Có emulator nhưng không chạy được app.

## Các bước chạy app

### Bước 1: Kiểm tra emulator có sẵn
```bash
flutter emulators
```

### Bước 2: Khởi động emulator
```bash
flutter emulators --launch Pixel_7_Pro
```

**Hoặc dùng Android Studio:**
1. Mở Android Studio
2. Tools → Device Manager
3. Click nút Play ▶️ bên cạnh emulator muốn chạy

### Bước 3: Đợi emulator khởi động hoàn toàn
- Thường mất 30-60 giây
- Đợi đến khi màn hình home của Android hiển thị
- Đợi icon loading biến mất

### Bước 4: Kiểm tra device đã sẵn sàng
```bash
flutter devices
```

Bạn sẽ thấy:
```
Android SDK built for x86_64 • emulator-5554 • android-x64 • Android 13 (API 33)
```

### Bước 5: Chạy app
```bash
flutter run
```

Hoặc chạy trên device cụ thể:
```bash
flutter run -d emulator-5554
```

## Troubleshooting

### 1. Emulator không hiển thị trong `flutter devices`

**Nguyên nhân:**
- Emulator chưa khởi động xong
- ADB chưa nhận diện emulator

**Giải pháp:**
```bash
# Kiểm tra ADB
adb devices

# Nếu không có device, restart ADB server
adb kill-server
adb start-server
adb devices
```

### 2. Lỗi "Android SDK location contains spaces"

Bạn đang gặp cảnh báo:
```
Android SDK location currently contains spaces, which is not supported
```

**Giải pháp:**
1. Tạo thư mục mới không có space: `C:\Android\Sdk`
2. Copy SDK từ `C:\Users\Anh Do\AppData\Local\Android\Sdk` sang `C:\Android\Sdk`
3. Set environment variable `ANDROID_HOME` = `C:\Android\Sdk`
4. Thêm `C:\Android\Sdk\platform-tools` vào PATH
5. Restart terminal và chạy lại `flutter doctor`

### 3. Emulator chạy nhưng app không cài được

**Kiểm tra:**
```bash
# Xem log chi tiết
flutter run -v

# Hoặc cài trực tiếp bằng ADB
adb install build\app\outputs\flutter-apk\app-debug.apk
```

### 4. Emulator quá chậm

**Tối ưu:**
1. Trong Android Studio Device Manager:
   - Edit emulator (icon bút chì)
   - Tăng RAM: 2048MB trở lên
   - Enable "Use Host GPU"
   - Chọn Graphics: Hardware - GLES 2.0

2. Trong Windows:
   - Bật Virtualization trong BIOS
   - Tắt Hyper-V nếu không cần
   - Tắt Windows Defender cho thư mục Android SDK (nếu quá chậm)

### 5. Lỗi "HAXM not installed" hoặc "Hyper-V conflict"

**Giải pháp:**
1. Nếu dùng Intel CPU:
   - Tải và cài Intel HAXM từ Android Studio SDK Manager
   - Hoặc tải từ: https://github.com/intel/haxm/releases

2. Nếu dùng AMD CPU hoặc gặp conflict với Hyper-V:
   - Dùng Android Emulator với Windows Hypervisor Platform (WHPX)
   - Trong Device Manager → Edit → Show Advanced Settings → Graphics: Software - GLES 2.0

### 6. Tạo emulator mới

Nếu cần tạo emulator mới:
```bash
flutter emulators --create --name my_emulator
```

Hoặc dùng Android Studio:
1. Tools → Device Manager
2. Create Device
3. Chọn device (ví dụ: Pixel 5)
4. Chọn system image (ví dụ: Android 13 API 33)
5. Finish

## Lệnh hữu ích

```bash
# Liệt kê emulators
flutter emulators

# Chạy emulator
flutter emulators --launch <emulator_id>

# Liệt kê devices đang kết nối
flutter devices

# Chạy app trên device cụ thể
flutter run -d <device_id>

# Hot reload (khi app đang chạy)
# Nhấn 'r' trong terminal

# Hot restart (khi app đang chạy)
# Nhấn 'R' trong terminal

# Xem logs
flutter logs

# Stop app
# Nhấn 'q' trong terminal
```

## Kiểm tra nhanh

Sau khi emulator khởi động, chạy lệnh này để verify:
```bash
adb devices
```

Nếu thấy:
```
List of devices attached
emulator-5554    device
```

Nghĩa là emulator đã sẵn sàng! ✅

