@echo off
REM ======================================================================
REM OverTime App - Auto Deploy Script
REM ======================================================================
echo.
echo =====================================================
echo 🚀 OVER TIME APP - AUTO DEPLOY
echo =====================================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python chưa được cài đặt!
    echo 📥 Hãy tải Python từ: https://www.python.org/downloads/
    echo Sau đó cài đặt và chạy lại script này.
    pause
    exit /b 1
)

REM Check if credentials.json exists
if not exist "tool\credentials.json" (
    echo ❌ Không tìm thấy file credentials.json!
    echo.
    echo 📋 Hướng dẫn setup:
    echo 1. Vào Google Cloud Console: https://console.cloud.google.com/
    echo 2. Tạo project mới
    echo 3. Bật Google Drive API
    echo 4. Tạo OAuth 2.0 credentials (Desktop app)
    echo 5. Download file JSON và đặt vào thư mục tool/credentials.json
    echo.
    echo 📖 Xem chi tiết: tool/README.md
    echo.
    pause
    exit /b 1
)

echo ✅ Tất cả requirements đã sẵn sàng!
echo 🔨 Đang deploy app...
echo.

REM Run the deploy script
python tool/deploy_overtime.py

if errorlevel 1 (
    echo.
    echo ❌ Deploy thất bại! Kiểm tra lỗi ở trên.
) else (
    echo.
    echo ✅ Deploy thành công!
    echo 📱 App của bạn đã được cập nhật tự động!
)

echo.
echo =====================================================
pause
