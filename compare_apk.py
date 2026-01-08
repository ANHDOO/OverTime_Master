import os
import hashlib

# Tính checksum của APK local
def get_file_hash(filepath):
    hash_md5 = hashlib.md5()
    with open(filepath, 'rb') as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

local_apk = 'build/app/outputs/flutter-apk/app-release.apk'
downloaded_apk = 'downloaded_apk.apk'

if os.path.exists(local_apk) and os.path.exists(downloaded_apk):
    local_hash = get_file_hash(local_apk)
    downloaded_hash = get_file_hash(downloaded_apk)

    print(f'Local APK hash: {local_hash}')
    print(f'Downloaded APK hash: {downloaded_hash}')

    if local_hash == downloaded_hash:
        print('OK: APK tren Drive khop voi APK local!')
    else:
        print('ERROR: APK tren Drive KHAC voi APK local!')

    # Kiểm tra kích thước
    local_size = os.path.getsize(local_apk)
    downloaded_size = os.path.getsize(downloaded_apk)
    print(f'Local size: {local_size:,} bytes')
    print(f'Downloaded size: {downloaded_size:,} bytes')

    if local_size == downloaded_size:
        print('OK: Kich thuoc khop!')
    else:
        print('ERROR: Kich thuoc KHONG khop!')
else:
    print('ERROR: Mot trong hai file APK khong ton tai')
    if not os.path.exists(local_apk):
        print(f'  - Local APK khong ton tai: {local_apk}')
    if not os.path.exists(downloaded_apk):
        print(f'  - Downloaded APK khong ton tai: {downloaded_apk}')


