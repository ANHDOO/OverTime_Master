import os
import json
from datetime import datetime
import urllib.request

# Kiểm tra file APK trong thư mục build
apk_path = 'build/app/outputs/flutter-apk/app-release.apk'
if os.path.exists(apk_path):
    size = os.path.getsize(apk_path)
    mtime = os.path.getmtime(apk_path)
    print(f'APK local: {apk_path}')
    print(f'Kich thuoc: {size:,} bytes ({size/1024/1024:.1f} MB)')
    print(f'Thoi gian sua: {datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")}')

    # So sanh voi metadata tren Drive
    print('\n--- Kiem tra metadata tren Drive ---')
    try:
        url = 'https://drive.google.com/uc?export=download&id=17HnOQ3CKafJ6IF4H_KIMerxpo8-Lrzuw'
        with urllib.request.urlopen(url) as response:
            data = json.loads(response.read().decode())
            print(f'Version trong metadata: {data["versionName"]} ({data["versionCode"]})')
            print(f'File size trong metadata: {data["fileSize"]}')
            print(f'Published: {data["publishedAt"][:19]}')

            # So sanh kich thuoc
            metadata_size = data["fileSize"]
            if 'MB' in metadata_size:
                metadata_mb = float(metadata_size.replace('MB', '').strip())
                local_mb = size/1024/1024
                print(f'So sanh kich thuoc: Local={local_mb:.1f}MB, Drive={metadata_mb}MB')
                if abs(local_mb - metadata_mb) < 0.1:
                    print('OK: Kich thuoc khop!')
                else:
                    print('ERROR: Kich thuoc KHONG khop!')
    except Exception as e:
        print(f'Loi khi tai metadata: {e}')
else:
    print('ERROR: APK khong ton tai trong thu muc build!')
