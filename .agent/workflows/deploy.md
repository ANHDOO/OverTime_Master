---
description: Quy trình Build và Deploy ứng dụng OverTime
---

Để đảm bảo chất lượng và thông tin đầy đủ cho người dùng, quy trình deploy phải tuân thủ các bước sau:

### 1. Kiểm tra lỗi Code
Trước khi build, phải đảm bảo code không có lỗi logic hoặc compile.
// turbo
- Chạy lệnh: `python tool/deploy_overtime.py --check`
- Nếu có lỗi (Error), phải sửa hết mới được đi tiếp.

### 2. Cập nhật Nhật ký thay đổi (Changelog)
Tạo file nhật ký thay đổi tại `release_notes/[version].md`.
- **Yêu cầu:** Nội dung phải được viết bằng **tiếng Việt**.
- **Đường dẫn ví dụ:** `D:\Project 2025\Note_OverTime\release_notes\1.0.6.md`
- Đảm bảo liệt kê đầy đủ tính năng mới và các lỗi đã fix.

### 3. Tăng Version Code
Cập nhật `version` trong `pubspec.yaml` (ví dụ: `1.0.6+36`).
Đảm bảo `versionCode` (số sau dấu +) luôn lớn hơn phiên bản cũ trên hệ thống.

### 4. Build và Deploy tự động
Sau khi đã kiểm tra và cập nhật thông tin, chạy script deploy full:
// turbo
- Lệnh: `python tool/deploy_overtime.py`
