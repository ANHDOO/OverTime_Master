# Khắc phục lỗi "Lost connection to device" và "device offline"

## Vấn đề
- ADB server version conflict (31 vs 41)
- Device offline
- Lost connection to device sau khi build

## Giải pháp nhanh

### Bước 1: Restart ADB Server
```bash
adb kill-server
adb start-server
```

### Bước 2: Kiểm tra emulator có đang chạy
```bash
flutter devices
```

Nếu không thấy emulator, tiếp tục bước 3.

### Bước 3: Khởi động lại emulator

**Cách A: Dùng Flutter**
```bash
flutter emulators --launch Pixel_7_Pro
```

**Cách B: Dùng Android Studio**
1. Mở Android Studio
2. Tools → Device Manager
3. Tìm emulator → Click nút Stop (nếu đang chạy)
4. Đợi 5 giây
5. Click nút Play ▶️ để khởi động lại

**Cách C: Dùng Command Line**
```bash
# Liệt kê emulators
emulator -list-avds

# Chạy emulator cụ thể (thay tên emulator của bạn)
emulator -avd Pixel_7_Pro
```

### Bước 4: Đợi emulator khởi động hoàn toàn
- Đợi 30-60 giây
- Đợi đến khi màn hình home Android hiển thị
- Đợi icon loading biến mất

### Bước 5: Verify connection
```bash
adb devices
```

Bạn sẽ thấy:
```
List of devices attached
emulator-5554    device
```

Nếu thấy `offline` hoặc `unauthorized`:
```bash
adb kill-server
adb start-server
adb devices
```

### Bước 6: Chạy app lại
```bash
flutter run
```

## Giải pháp chi tiết

### 1. Fix ADB Version Conflict

**Vấn đề:** Có nhiều version ADB khác nhau trong PATH

**Giải pháp:**
1. Tìm tất cả adb.exe trong máy:
   ```powershell
   Get-ChildItem -Path C:\ -Filter adb.exe -Recurse -ErrorAction SilentlyContinue | Select-Object FullName
   ```

2. Chỉ giữ lại ADB từ Android SDK mới nhất:
   - Thường ở: `C:\Users\<YourName>\AppData\Local\Android\Sdk\platform-tools\adb.exe`
   - Hoặc: `C:\Android\Sdk\platform-tools\adb.exe`

3. Xóa hoặc đổi tên các ADB cũ khác

4. Đảm bảo PATH chỉ trỏ đến ADB mới:
   ```powershell
   # Kiểm tra PATH
   $env:PATH -split ';' | Select-String -Pattern "platform-tools"
   
   # Set PATH (nếu cần)
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\<YourName>\AppData\Local\Android\Sdk\platform-tools", "User")
   ```

### 2. Fix Device Offline

**Nguyên nhân:**
- Emulator chưa khởi động xong
- USB debugging chưa được enable
- ADB server crash

**Giải pháp:**
```bash
# Restart ADB
adb kill-server
adb start-server

# Kiểm tra lại
adb devices

# Nếu vẫn offline, restart emulator
```

### 3. Fix Lost Connection

**Nguyên nhân:**
- Emulator crash
- Emulator restart tự động
- Network issue giữa Flutter và emulator

**Giải pháp:**

**A. Restart emulator hoàn toàn:**
```bash
# Tắt emulator
adb -s emulator-5554 emu kill

# Hoặc đóng từ Android Studio Device Manager

# Khởi động lại
flutter emulators --launch Pixel_7_Pro
```

**B. Tăng timeout:**
```bash
flutter run --device-timeout 30
```

**C. Chạy với verbose để xem log:**
```bash
flutter run -v
```

### 4. Emulator Crash Thường Xuyên

**Tối ưu emulator:**

1. **Tăng RAM:**
   - Android Studio → Device Manager
   - Edit emulator (icon bút chì)
   - Advanced Settings → RAM: 2048MB hoặc 4096MB

2. **Enable Hardware Acceleration:**
   - Edit emulator → Advanced Settings
   - Graphics: Hardware - GLES 2.0
   - Enable "Use Host GPU"

3. **Giảm Resolution:**
   - Edit emulator → Advanced Settings
   - Resolution: 1080x1920 (thay vì cao hơn)

4. **Tắt Hyper-V (nếu không cần):**
   ```powershell
   # Chạy với quyền Admin
   Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
   ```

### 5. Cold Boot Emulator

Nếu emulator vẫn không ổn định, thử cold boot:

```bash
# Tắt emulator hoàn toàn
adb -s emulator-5554 emu kill

# Cold boot (xóa cache)
emulator -avd Pixel_7_Pro -wipe-data

# Hoặc từ Android Studio:
# Device Manager → Dropdown menu emulator → Cold Boot Now
```

## Lệnh hữu ích

```bash
# Kiểm tra ADB version
adb version

# Kiểm tra devices
adb devices -l

# Restart ADB
adb kill-server && adb start-server

# Xem log emulator
adb logcat

# Xem log Flutter
flutter logs

# Kiểm tra emulator đang chạy
tasklist | findstr qemu

# Kill tất cả emulator processes
taskkill /F /IM qemu-system-x86_64.exe
```

## Checklist khi gặp lỗi

- [ ] Restart ADB server (`adb kill-server && adb start-server`)
- [ ] Kiểm tra emulator có đang chạy (`flutter devices`)
- [ ] Restart emulator nếu cần
- [ ] Đợi emulator khởi động hoàn toàn (30-60 giây)
- [ ] Verify connection (`adb devices` phải hiển thị `device` không phải `offline`)
- [ ] Chạy lại với verbose (`flutter run -v`) để xem log chi tiết
- [ ] Nếu vẫn lỗi, thử cold boot emulator

## Nếu vẫn không được

1. **Restart máy tính** - đôi khi Windows cần restart để fix connection issues

2. **Kiểm tra Windows Firewall/Antivirus:**
   - Có thể block connection giữa Flutter và emulator
   - Thử tạm thời disable để test

3. **Reinstall Android SDK Platform Tools:**
   - Android Studio → SDK Manager
   - SDK Tools tab
   - Uncheck và check lại "Android SDK Platform-Tools"
   - Apply

4. **Tạo emulator mới:**
   - Có thể emulator hiện tại bị corrupt
   - Tạo emulator mới từ Android Studio

