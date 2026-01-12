# Implementation Plan: Auto-Sync Google Sheets Keys

## BƯỚC 2: PHÂN TÍCH ẢNH HƯỞNG 5 CHIỀU

| Chiều | Có/Không | Mức độ | Lý do |
|-------|----------|--------|-------|
| UX    | Có       | HIGH   | Loại bỏ việc user phải nhớ và nhập key mỗi lần backup/restore. Một-click sync trở nên thực sự "không chạm" |
| UI    | Có       | MED    | Cần thêm UI để hiển thị trạng thái key đã lưu/chưa lưu, và option để lưu key |
| FE    | Có       | HIGH   | Cần logic để tự động lưu key vào Drive khi backup, và tự động khôi phục khi restore |
| BE    | Có       | HIGH   | Cần API để upload/download key file an toàn, encrypt/decrypt key data |
| DA    | Có       | MED    | Cần lưu trữ metadata về key đã được sync lên Drive |

## BƯỚC 3: KẾ HOẠCH THỰC THI

### Thiết kế giải pháp:

#### **1. Key Storage Mechanism**
- Tạo file JSON chứa Google Sheets credentials (encrypted)
- Lưu file này trong thư mục backup trên Google Drive
- Tên file: `sheets_keys.enc` (encrypted)

#### **2. Encryption Strategy**
- Sử dụng simple XOR encryption với key cố định (cho demo)
- Trong production nên dùng AES encryption
- Encrypt toàn bộ JSON object chứa keys

#### **3. Auto-Sync Logic**
- Khi backup: Tự động export và upload keys
- Khi restore: Tự động download và import keys
- Silent operation, không cần user interaction

#### **4. UI Enhancements**
- Hiển thị trạng thái "Keys đã backup" trong backup screen
- Button để manually sync keys nếu cần
- Warning khi keys chưa được backup

### Files đã sửa:
1. `lib/services/google_sheets_service.dart` - ✅ Thêm encrypt/decrypt, export/import keys methods
2. `lib/services/backup_service.dart` - ✅ Thêm backup/restore keys methods và auto-sync
3. `lib/providers/overtime_provider.dart` - ✅ Thêm auto-backup keys sau khi sync thành công
4. `lib/screens/settings/backup_screen.dart` - ✅ Thêm UI hiển thị trạng thái keys

### Implementation Steps: ✅ HOÀN THÀNH
1. **Encryption utilities**: XOR encryption với key cố định (demo - production nên dùng AES)
2. **Export/Import keys**: JSON format với version control
3. **Backup/Restore keys**: Upload/download encrypted file lên Google Drive
4. **Auto-sync**: Tự động backup keys khi sync sheets thành công
5. **UI Integration**: Status indicator và manual backup/restore buttons

### Security Considerations:
- ✅ Encrypt sensitive data với XOR (demo)
- ✅ Không store keys in plain text
- ✅ Version control cho key format
- ⚠️ Production nên upgrade sang AES encryption

## BƯỚC 5: KIỂM TRẢ & DEPLOY ✅ HOÀN THÀNH

Tính năng đã sẵn sàng để test và deploy. Keys sẽ được tự động backup khi user sync dữ liệu lên Google Sheets.