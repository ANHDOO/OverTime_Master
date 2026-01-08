# Hướng dẫn khắc phục lỗi kiểm tra cập nhật tự động

## Vấn đề
App không thể tự động kiểm tra bản cập nhật mới từ Google Drive, phải cập nhật thủ công.

## Nguyên nhân có thể

### 1. File metadata.json không tồn tại hoặc File ID sai

**Kiểm tra:**
- Mở folder Google Drive: https://drive.google.com/drive/u/0/folders/1NjHCrZyZohQnRptgZL62G7LUTEFL66YY
- Kiểm tra xem có file `metadata.json` (hoặc `latest_metadata.json`) trong folder không
- Nếu không có, bạn cần tạo file này

**Cách tạo file metadata.json:**
1. Tạo file JSON với nội dung:
```json
{
  "versionCode": 2,
  "versionName": "1.0.1",
  "downloadUrl": "https://drive.google.com/uc?export=download&id=YOUR_APK_FILE_ID",
  "changelog": "Cập nhật mới:\n- Sửa lỗi...\n- Thêm tính năng...",
  "fileSize": "25 MB"
}
```

2. Thay đổi các giá trị:
   - `versionCode`: Số build number mới (phải lớn hơn version hiện tại trong pubspec.yaml)
   - `versionName`: Tên phiên bản (ví dụ: "1.0.1")
   - `downloadUrl`: Link download APK từ Google Drive
   - `changelog`: Mô tả các thay đổi
   - `fileSize`: Kích thước file APK

### 2. File không được share public

**Cách kiểm tra và sửa:**
1. Right-click vào file `metadata.json` trên Google Drive
2. Chọn "Share" hoặc "Chia sẻ"
3. Trong phần "General access" hoặc "Quyền truy cập chung":
   - Chọn "Anyone with the link" hoặc "Bất kỳ ai có liên kết"
   - Role: "Viewer" hoặc "Người xem"
4. Click "Done" hoặc "Xong"

### 3. File ID trong code không đúng

**Cách lấy đúng File ID:**
1. Right-click vào file `metadata.json` trên Google Drive
2. Chọn "Share" hoặc "Chia sẻ"
3. Copy link share (ví dụ: `https://drive.google.com/file/d/ABC123XYZ456/view?usp=sharing`)
4. File ID là phần giữa `/d/` và `/view`
   - Ví dụ: Nếu link là `https://drive.google.com/file/d/ABC123XYZ456/view`
   - File ID là: `ABC123XYZ456`

**Cách cập nhật File ID trong code:**
1. Mở file `lib/services/update_service.dart`
2. Tìm dòng:
   ```dart
   static const String METADATA_FILE_ID = '17HnOQ3CKafJ6IF4H_KIMerxpo8-Lrzuw';
   ```
3. Thay thế File ID cũ bằng File ID mới:
   ```dart
   static const String METADATA_FILE_ID = 'ABC123XYZ456';
   ```

### 4. Link download APK không đúng

**Kiểm tra downloadUrl trong metadata.json:**
- Link phải là direct download link từ Google Drive
- Format: `https://drive.google.com/uc?export=download&id=YOUR_APK_FILE_ID`
- APK file cũng phải được share public giống như metadata.json

## Cách test

### Test trong app:
1. Mở app
2. Vào Settings (Cài đặt)
3. Click "Kiểm tra cập nhật"
4. Kiểm tra log trong console để xem chi tiết lỗi:
   - Nếu thành công: "✅ Successfully parsed metadata JSON"
   - Nếu lỗi: "❌ Failed to fetch metadata" hoặc "❌ Error parsing metadata"

### Test trực tiếp trên trình duyệt:
1. Mở link sau trong trình duyệt (thay YOUR_FILE_ID):
   ```
   https://drive.google.com/uc?export=download&id=YOUR_FILE_ID
   ```
2. Nếu thấy nội dung JSON, link đúng
3. Nếu thấy trang HTML hoặc lỗi, file chưa được share public

## Debug log

Sau khi cập nhật code, app sẽ hiển thị log chi tiết trong console:
- `📱 Current app version`: Version hiện tại của app
- `🔄 Attempting to fetch metadata`: Đang thử fetch metadata
- `📡 Response status`: HTTP status code
- `✅ Successfully parsed metadata JSON`: Thành công
- `❌ Failed to fetch metadata`: Lỗi fetch
- `🌐 Remote version`: Version trên server
- `✨ New version available!`: Có bản mới

## Checklist

Trước khi test lại, đảm bảo:
- [ ] File metadata.json tồn tại trong Google Drive folder
- [ ] File metadata.json được share public (Anyone with the link can view)
- [ ] File ID trong code đúng với file trên Drive
- [ ] Version code trong metadata.json lớn hơn version hiện tại
- [ ] Link downloadUrl trong metadata.json đúng và APK file cũng public
- [ ] Format JSON đúng (có thể test bằng JSON validator)

