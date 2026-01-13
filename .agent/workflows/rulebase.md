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

### Điều 4: Nguyên tắc Tập trung (Focus & Context)
AI Agent PHẢI:
- Luôn bám sát ngữ cảnh dự án `OverTime`.
- Không trả lời lan man, không đề xuất các tính năng nằm ngoài phạm vi yêu cầu trừ khi có lý lẽ kỹ thuật chặt chẽ.
- Mọi phản hồi phải dựa trên dữ liệu thực tế từ codebase hiện tại.

---

## CHƯƠNG III: CƠ CHẾ TỰ KIỂM TRA (SELF-VERIFICATION)

### BƯỚC 6: TỰ ĐÁNH GIÁ CÂU TRẢ LỜI
Trước khi gửi bất kỳ phản hồi nào cho người dùng, AI Agent PHẢI tự trả lời 3 câu hỏi:
1. **Tính tập trung:** Câu trả lời có đang bám sát `PROJECT_STATE.md` và yêu cầu hiện tại không? (Có/Không)
2. **Tính thực tế:** Giải pháp có dựa trên codebase hiện tại, hay đang đề xuất lý thuyết suông? (Thực tế/Lý thuyết)
3. **Tính quy trình:** Đã thực hiện đủ các bước từ 1-5 chưa? (Đã xong/Chưa)

**CẤM:** Gửi câu trả lời nếu có bất kỳ câu trả lời nào là "Không", "Lý thuyết" hoặc "Chưa".

---

## CHƯƠNG IV: QUY TRÌNH 5 BƯỚC BẮT BUỘC

### BƯỚC 1: TIẾP NHẬN
- **PHẢI**: Đọc `PROJECT_STATE.md`, xác định loại yêu cầu (Feature/Bug/Refactor/Optimize).
- **KIỂM TRA**: Đối chiếu yêu cầu với Điều 4 (Nguyên tắc Tập trung). Nếu yêu cầu nằm ngoài phạm vi hoặc không rõ ràng, PHẢI yêu cầu làm rõ trước khi tiếp tục.
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

### BƯỚC 6: TỰ KIỂM TRA (SELF-CHECK)
Thực hiện theo Chương III trước khi phản hồi.
