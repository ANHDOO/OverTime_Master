# Hướng dẫn sửa lỗi "Building with plugins requires symlink support" trên Windows

## Lỗi
```
Building with plugins requires symlink support.

Please enable Developer Mode in your system settings. Run
  start ms-settings:developers
to open settings.
```

## Nguyên nhân
Windows cần Developer Mode để hỗ trợ symbolic links (symlink), mà Flutter sử dụng khi build plugins.

## Cách 1: Bật Developer Mode (Khuyên dùng)

### Bước 1: Mở Settings
Có 3 cách:

**Cách A: Chạy lệnh (Nhanh nhất)**
- Nhấn `Windows + R`
- Gõ: `ms-settings:developers`
- Nhấn Enter

**Cách B: Từ Start Menu**
- Nhấn `Windows + I` để mở Settings
- Tìm "Privacy & security" hoặc "Bảo mật và quyền riêng tư"
- Click "For developers" hoặc "Dành cho nhà phát triển"

**Cách C: Từ PowerShell/Terminal**
```powershell
start ms-settings:developers
```

### Bước 2: Bật Developer Mode
1. Trong trang "For developers" / "Dành cho nhà phát triển"
2. Tìm phần "Developer Mode" / "Chế độ dành cho nhà phát triển"
3. Bật toggle switch sang ON
4. Windows có thể yêu cầu restart hoặc xác nhận, làm theo hướng dẫn

### Bước 3: Verify
Sau khi bật, thử build lại:
```bash
flutter clean
flutter pub get
flutter build apk
```

## Cách 2: Dùng Group Policy (Nếu không có Developer Mode)

Nếu Windows của bạn không có Developer Mode (Windows 10 Home), có thể dùng cách này:

### Bước 1: Mở Local Security Policy
1. Nhấn `Windows + R`
2. Gõ: `secpol.msc`
3. Nhấn Enter
4. Nếu không mở được (Windows Home không có), skip sang Cách 3

### Bước 2: Chỉnh sửa quyền
1. Navigate: Security Settings → Local Policies → User Rights Assignment
2. Tìm "Create symbolic links" / "Tạo liên kết tượng trưng"
3. Double-click để mở
4. Click "Add User or Group"
5. Add user hiện tại (hoặc "Users" group)
6. OK và apply

## Cách 3: Chạy PowerShell/CMD với quyền Admin (Tạm thời)

Nếu không thể bật Developer Mode, có thể chạy build với quyền admin:

### Bước 1: Mở PowerShell/CMD với quyền Admin
1. Right-click vào Start menu
2. Chọn "Windows PowerShell (Admin)" hoặc "Terminal (Admin)"
3. Xác nhận UAC prompt

### Bước 2: Navigate đến project và build
```powershell
cd "D:\Project 2025\Note_OverTime"
flutter clean
flutter pub get
flutter build apk
```

**Lưu ý:** Cách này chỉ là tạm thời. Nên bật Developer Mode để tránh phải chạy admin mỗi lần.

## Cách 4: Dùng WSL2 (Windows Subsystem for Linux)

Nếu các cách trên không hoạt động, có thể build trên WSL2:

1. Cài WSL2 và Ubuntu
2. Cài Flutter trên WSL2
3. Build từ WSL2 terminal

## Kiểm tra Developer Mode đã bật

Sau khi bật, kiểm tra bằng lệnh:
```powershell
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /v AllowDevelopmentWithoutDevLicense
```

Nếu trả về `0x1` thì đã bật.

## Troubleshooting

### Vẫn gặp lỗi sau khi bật Developer Mode:
1. **Restart máy** sau khi bật Developer Mode
2. **Flutter clean** và build lại:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```
3. **Kiểm tra quyền user**: Đảm bảo đang dùng admin account hoặc user có quyền đầy đủ
4. **Kiểm tra Windows version**: Developer Mode có từ Windows 10 version 1703 trở lên

### Windows không có Developer Mode:
- Windows 10 Home có thể không có Developer Mode
- Cần upgrade lên Windows 10 Pro/Enterprise hoặc Windows 11
- Hoặc dùng Cách 2 (Group Policy) hoặc Cách 3 (Admin)

### Lỗi permission denied:
- Đảm bảo đã restart sau khi bật Developer Mode
- Thử chạy terminal/PowerShell với quyền admin
- Kiểm tra antivirus có block symlink không

## Tài liệu tham khảo
- [Microsoft: Enable your device for development](https://docs.microsoft.com/en-us/windows/apps/get-started/enable-your-device-for-development)
- [Flutter Windows requirements](https://docs.flutter.dev/get-started/install/windows)

