# PROJECT STATE - OverTime

## Tổng quan dự án
Ứng dụng quản lý giờ tăng ca (Overtime) cá nhân, hỗ trợ tính lương, xuất báo cáo Excel và sao lưu Google Drive.

- **Current Version:** 1.3.4+50
- **Status:** Active Development (UX/UI Polish Phase)

## Công nghệ sử dụng
- **Frontend:** Flutter (Dart)
- **State Management:** Provider
- **Database:** Sqflite (Local)
- **Services:** Google Sign-In, Google Drive API, Local Notifications
- **Tooling:** Python (Deploy script)

## Chi tiết tính năng hiện có

### 1. Quản lý Tăng ca (Overtime)
- Nhập giờ làm theo 3 chế độ: Chọn giờ cụ thể, Nhập tổng số giờ, hoặc Chia nhiều ca.
- Tự động tính lương theo hệ số: 1.5x (ngày thường), 1.8x (làm đêm), 2.0x (chủ nhật).
- **Mới:** Swipe để Xóa/Sửa, Sao chép bản ghi, Template nhanh (⚡), Hoàn tác (Undo).

### 2. Quỹ Dự Án (Cash Flow)
- Theo dõi thu chi theo từng dự án riêng biệt.
- Phân loại giao dịch (Thu nhập, Chi phí).
- Thống kê số dư hiện tại của từng quỹ.

### 3. Quản lý Lãi nợ (Debt)
- Theo dõi các khoản nợ và tính toán lãi suất.
- Quản lý danh sách nợ theo tháng.

### 4. Công cụ tính toán (Calculators)
- **PIT Calculator:** Tính thuế thu nhập cá nhân (PIT) theo quy định mới nhất.
- **Interest Calculator:** Tính lãi suất vay/gửi.

### 5. Thống kê & Báo cáo (Statistics)
- **Premium Line Charts:** Biểu đồ đường cong mềm mại với gradient và tooltip tương tác.
- Xuất báo cáo Excel chuyên nghiệp cho kế toán (font Times New Roman, định dạng chuẩn).

### 6. Hệ thống & Bảo mật
- **Backup:** Sao lưu và khôi phục dữ liệu qua Google Drive.
- **Silent Sign-In:** Tự động kết nối Google Drive khi khởi động app.
- **Security:** Khóa ứng dụng bằng mã PIN (Lock Screen).
- **Update:** Hệ thống tự động kiểm tra và thông báo cập nhật từ GitHub.

---

## Lộ trình phát triển (Roadmap)

### Giai đoạn 1: Tối ưu hóa & Ổn định (Hoàn tất)
- [x] Triển khai Rulebase và quy trình Deploy chuẩn.
- [x] Cải thiện UX (Swipe, Copy, Templates).
- [x] Premium Line Charts & Silent Sign-In Fix.

### Giai đoạn 2: Mở rộng tính năng
- [ ] **Báo cáo nâng cao:** Thêm biểu đồ so sánh thu nhập giữa các tháng/năm.
- [ ] **Quản lý mục tiêu:** Đặt mục tiêu thu nhập tháng và theo dõi tiến độ.
- [ ] **Widget:** Thêm widget màn hình chính để xem nhanh tổng giờ OT trong tháng.
- [x] **Citizen Search Hub (Completed):** Phân hệ tra cứu đa năng với tính năng lưu hồ sơ cá nhân thông minh.

### Giai đoạn 3: Thông minh hóa
- [ ] **AI Assistant:** Tích hợp chatbot hỗ trợ giải đáp thắc mắc về lương, thuế.
- [ ] **Tự động hóa:** Nhận diện giờ làm từ ảnh chụp bảng chấm công (OCR).
- [ ] **Đa ngôn ngữ:** Hỗ trợ thêm tiếng Anh.
