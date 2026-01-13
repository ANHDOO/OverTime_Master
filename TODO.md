# TODO - Công việc cần làm tiếp

## 🔴 Ưu tiên cao

### 1. Giá xăng dầu realtime
**File**: `lib/services/info_service.dart`
**Hàm**: `getFuelPrices()`

**Vấn đề**: Hiện tại đang hardcode giá xăng cố định, không lấy realtime.

**Cần làm**:
- Tìm nguồn API hoặc website giá xăng Việt Nam (ví dụ: petrolimex.com.vn)
- Implement scrape HTML hoặc gọi API để lấy giá realtime
- Tham khảo cách làm của `getTamNhungGoldPrices()` (scrape HTML)

---

## ✅ Đã hoàn thành (13/01/2026)

- Biểu đồ giá vàng & Bảng giá SJC (gold_price_detail_screen.dart)
- Lấy giá xăng dầu realtime từ webgia.com (info_service.dart)
- Sửa lỗi dependents.isEmpty khi tạo PIN & Cleanup code (security_screen.dart)
- Sửa lỗi RenderFlex unbounded height (update_screen.dart)
- Sửa lỗi overflow tag dự án (cash_flow_tab.dart)
- Tự động restore Sheet Keys khi restore database (backup_screen.dart)
- Deploy v1.3.5+52
