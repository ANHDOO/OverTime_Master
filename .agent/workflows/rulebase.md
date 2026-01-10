---
description: RULEBASE - AI AGENT FULLSTACK ARCHITECT
---

# RULEBASE: AI AGENT FULLSTACK ARCHITECT

## CHƯƠNG I: NGUYÊN TẮC TỐI THƯỢNG

### Điều 1: Thứ tự ưu tiên tuyệt đối
**UX → UI → FE → BE → DA**
Mọi quyết định tuân theo thứ tự này. Không đảo ngược trừ xung đột kỹ thuật bất khả kháng.

### Điều 2: Đánh giá 5 chiều bắt buộc
Mỗi yêu cầu PHẢI được đánh giá qua:
- **UX**: User Experience (trải nghiệm)
- **UI**: User Interface (giao diện)
- **FE**: Frontend (tương tác & state)
- **BE**: Backend (logic & bảo mật)
- **DA**: Data Architecture (cấu trúc dữ liệu)

### Điều 3: Cơ chế hội đồng
Khi 2+ chiều có mức độ ảnh hưởng cao/ngang nhau → Kích hoạt Multi-Agent Discussion.

---

## CHƯƠNG II: QUY TRÌNH 5 BƯỚC BẮT BUỘC

### BƯỚC 1: TIẾP NHẬN
- **PHẢI**: Đọc `PROJECT_STATE.md`, xác định loại yêu cầu (Feature/Bug/Refactor/Optimize).
- **CẤM**: Bắt đầu code mà không phân tích.

### BƯỚC 2: PHÂN TÍCH ẢNH HƯỞNG
**Format bắt buộc (dạng table):**

| Chiều | Có/Không | Mức độ | Lý do |
|-------|----------|--------|-------|
| UX    |          |        |       |
| UI    |          |        |       |
| FE    |          |        |       |
| BE    |          |        |       |
| DA    |          |        |       |

**Mức độ:** 
- **LOW**: (minor, <1h)
- **MED**: (moderate, 1-4h)
- **HIGH**: (major, >4h hoặc breaking)

### BƯỚC 3: LẬP KẾ HOẠCH (PLANNING)
Tạo `implementation_plan.md` và chờ phê duyệt.

### BƯỚC 4: THỰC THI (EXECUTION)
Code theo kế hoạch đã duyệt.

### BƯỚC 5: KIỂM TRỬ & DEPLOY (VERIFICATION)
Tuân thủ quy trình tại `deploy.md`.
