# OverTime - Sổ Tay Công Việc & Quản Lý Thu Nhập

Ứng dụng Flutter giúp quản lý giờ làm thêm (OT), theo dõi nợ lương, và quản lý ngân sách dự án một cách thông minh.

## 🚀 Tính năng chính

- **Quản lý OT:** Ghi chép giờ làm thêm, tính toán thu nhập dự kiến.
- **Theo dõi Nợ lương:** Quản lý các khoản nợ lương theo tháng, nhắc nhở hạn thanh toán.
- **Quản lý Ngân sách:** Theo dõi chi tiêu dự án, cảnh báo khi vượt định mức.
- **Thông báo thông minh:** Nhắc nhở nhập OT hằng ngày và các sự kiện quan trọng.
- **Đồng bộ Google Sheets:** Tự động đồng bộ dữ liệu lên Google Sheets để quản lý tập trung.
- **Tính thuế PIT:** Công cụ tính thuế thu nhập cá nhân tích hợp.

## 📂 Cấu trúc dự án

- `lib/`: Mã nguồn chính của ứng dụng Flutter.
- `docs/`: Tài liệu hướng dẫn cài đặt và cấu hình.
- `tool/`: Các script hỗ trợ build, deploy và quản lý dữ liệu.
- `assets/`: Hình ảnh, font và các tài nguyên khác.

## 📖 Tài liệu hướng dẫn

Xem chi tiết các hướng dẫn trong thư mục [docs/](docs/):
- [Hướng dẫn cài đặt Google Sheets](docs/GOOGLE_SHEETS_SETUP.md)
- [Hướng dẫn thiết lập Google Sign-In](docs/GOOGLE_SIGN_IN_SETUP.md)
- [Hướng dẫn Deploy APK](docs/DEPLOYMENT_GUIDE.md)
- [Sửa lỗi kết nối Emulator](docs/FIX_EMULATOR_CONNECTION.md)

## 🛠️ Phát triển

### Yêu cầu hệ thống
- Flutter SDK: ^3.10.3
- Dart SDK: ^3.0.0

### Cài đặt
1. Clone repository: `git clone https://github.com/ANHDOO/OverTime_Master.git`
2. Cài đặt dependencies: `flutter pub get`
3. Chạy ứng dụng: `flutter run`

---
_Phát triển bởi Lý Anh Đô_
