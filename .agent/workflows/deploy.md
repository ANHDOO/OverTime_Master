---
description: Quy trình Build và Deploy ứng dụng OverTime
---

# Quy trình Build và Deploy ứng dụng OverTime

> [!IMPORTANT]
> Luôn tuân thủ **RULEBASE** tại [.agent/workflows/rulebase.md](file:///d:/Project%202025/Note_OverTime/.agent/workflows/rulebase.md) trước khi thực hiện bất kỳ thay đổi nào.

Để đảm bảo chất lượng và thông tin đầy đủ cho người dùng, quy trình deploy phải tuân thủ các bước sau:

### 1. Kiểm tra lỗi Code
Trước khi build, phải đảm bảo code không có lỗi logic hoặc compile.
// turbo
- Chạy lệnh: `python tool/deploy_overtime.py --check`
- Nếu có lỗi (Error), phải sửa hết mới được đi tiếp.

### 2. Cập nhật Nhật ký thay đổi (Changelog)
Mở file `release_notes/1.0.5.md` (hoặc version tương ứng) và cập nhật:
- Build number mới nhất.
- Danh sách các tính năng mới, cải thiện hoặc sửa lỗi.
- Đảm bảo ngôn ngữ dễ hiểu cho người dùng.

### 3. Tăng Version Code
Cập nhật `version` trong `pubspec.yaml` (ví dụ: `1.0.5+35`).

### 4. Build và Deploy tự động
Sau khi đã kiểm tra và cập nhật thông tin, chạy script deploy full:
// turbo
- Lệnh: `python tool/deploy_overtime.py`

### 5. Kiểm tra Git
Đảm bảo các thay đổi về code và release notes đã được push lên đúng repo:
- Code: `OverTime_Master`
- Metadata: `OverTime_Updates`
