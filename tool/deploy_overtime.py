"""
Deploy APK to Google Drive với tự động tạo thư mục version và README
Script để build APK và upload lên Google Drive theo cấu trúc version

Usage:
    python tool/deploy_overtime.py

Requirements:
    pip install pyyaml google-auth-oauthlib google-api-python-client
"""

import os
import sys
import yaml
import json
import subprocess
import pickle
from datetime import datetime
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from googleapiclient.errors import HttpError
import time

# === CONFIGURATION ===
PUBSPEC_PATH = 'pubspec.yaml'
APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
RELEASE_NOTES_DIR = 'release_notes'
UPDATE_SERVICE_PATH = 'lib/services/update_service.dart'

# Google Drive Config
DRIVE_CREDENTIALS_FILE = 'tool/credentials.json'
DRIVE_TOKEN_FILE = 'tool/token.pickle'
DRIVE_PARENT_FOLDER_ID = '1NjHCrZyZohQnRptgZL62G7LUTEFL66YY'  # Folder gốc trên Drive
DRIVE_SCOPES = ['https://www.googleapis.com/auth/drive.file']
# Tăng chunk size lên 8MB để giảm số request và thường nhanh hơn trên kết nối ổn định
DRIVE_CHUNK_SIZE = 8 * 1024 * 1024  # 8MB chunks
MAX_UPLOAD_RETRIES = 5
RETRY_BACKOFF_BASE = 2

# === UTILS ===

def log(message):
    print(message)

def format_size(bytes):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes < 1024:
            return f"{bytes:.1f}{unit}"
        bytes /= 1024
    return f"{bytes:.1f}TB"

def update_metadata_file_id_in_code(file_id):
    """Cập nhật METADATA_FILE_ID trong update_service.dart"""
    if not os.path.exists(UPDATE_SERVICE_PATH):
        log(f"[!] Khong tim thay file {UPDATE_SERVICE_PATH}")
        return False
    
    try:
        with open(UPDATE_SERVICE_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Tìm và thay thế METADATA_FILE_ID
        import re
        old_pattern = r"static const String METADATA_FILE_ID = '[^']*';"
        new_value = f"static const String METADATA_FILE_ID = '{file_id}';"
        
        if re.search(old_pattern, content):
            new_content = re.sub(old_pattern, new_value, content)
            
            with open(UPDATE_SERVICE_PATH, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            log(f"[OK] Da cap nhat METADATA_FILE_ID = '{file_id}' trong update_service.dart")
            return True
        else:
            log(f"[!] Khong tim thay METADATA_FILE_ID trong {UPDATE_SERVICE_PATH}")
            return False
    except Exception as e:
        log(f"[X] Loi khi cap nhat METADATA_FILE_ID: {e}")
        return False

def get_version():
    """Lấy version từ pubspec.yaml"""
    with open(PUBSPEC_PATH, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
        version = data.get('version', '1.0.0')
        return version.split('+')[0]

def get_version_code():
    """Lấy version code (build number) từ pubspec.yaml"""
    with open(PUBSPEC_PATH, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)
        version = data.get('version', '1.0.0+1')
        if '+' in version:
            return int(version.split('+')[1])
        return 1

def get_release_notes(version):
    """Đọc release notes từ file hoặc tạo mặc định"""
    notes_file = os.path.join(RELEASE_NOTES_DIR, f'{version}.md')
    if os.path.exists(notes_file):
        with open(notes_file, 'r', encoding='utf-8') as f:
            return f.read()
    
    # Tạo README mặc định
    return f"""# OverTime v{version}

## Thong tin phien ban
- **Version:** {version}
- **Build:** {get_version_code()}
- **Ngày phát hành:** {datetime.now().strftime('%d/%m/%Y')}

## Tinh nang moi
- Cải thiện hiệu suất và ổn định
- Sửa lỗi nhỏ

## 📥 Hướng dẫn cài đặt
1. Tải file APK về thiết bị Android
2. Cho phép cài đặt từ nguồn không xác định trong Settings
3. Mở file APK và cài đặt

---
_Phát hành tự động bởi hệ thống build_
"""

def build_apk():
    """Build APK release"""
    log("\n[+] Building APK...")
    try:
        subprocess.run(['flutter', 'clean'], check=True)
        result = subprocess.run(
            ['flutter', 'build', 'apk', '--release'],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            raise Exception(f"Build failed: {result.stderr}")
        log("[OK] Build thanh cong!")
        return True
    except Exception as e:
        log(f"[X] Build error: {e}")
        return False

# === GOOGLE DRIVE FUNCTIONS ===

def get_drive_service():
    """Lấy Google Drive service với OAuth"""
    creds = None
    if os.path.exists(DRIVE_TOKEN_FILE):
        with open(DRIVE_TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(DRIVE_CREDENTIALS_FILE):
                raise Exception(f"Không tìm thấy {DRIVE_CREDENTIALS_FILE}. Vui lòng tải credentials.json từ Google Cloud Console.")
            flow = InstalledAppFlow.from_client_secrets_file(
                DRIVE_CREDENTIALS_FILE, DRIVE_SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(DRIVE_TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)
    
    return build('drive', 'v3', credentials=creds)

def find_or_create_folder(service, folder_name, parent_id):
    """Tìm hoặc tạo thư mục trên Drive"""
    query = f"name = '{folder_name}' and '{parent_id}' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
    res = service.files().list(q=query, fields="files(id, name)").execute()
    files = res.get('files', [])
    
    if files:
        folder_id = files[0]['id']
        log(f"[i] Thu muc '{folder_name}' da ton tai (ID: {folder_id})")
        return folder_id
    else:
        meta = {
            'name': folder_name,
            'mimeType': 'application/vnd.google-apps.folder',
            'parents': [parent_id]
        }
        folder = service.files().create(body=meta, fields='id').execute()
        folder_id = folder.get('id')
        log(f"[OK] Da tao thu muc '{folder_name}' (ID: {folder_id})")
        return folder_id

def upload_file(service, file_path, file_name, folder_id, mimetype=None):
    """Upload file lên Drive"""
    if not os.path.exists(file_path):
        raise Exception(f"File không tồn tại: {file_path}")
    
    # Kiểm tra file đã tồn tại chưa
    query = f"name = '{file_name}' and '{folder_id}' in parents and trashed = false"
    res = service.files().list(q=query, fields="files(id)").execute()
    existing_files = res.get('files', [])
    
    if existing_files:
        file_id = existing_files[0]['id']
        
        # Nếu là metadata file thì update content
        if file_name == 'latest_metadata.json':
            log(f"[+] Updating existing file '{file_name}' (ID: {file_id})...")
            
            media = MediaFileUpload(
                file_path,
                mimetype=mimetype,
                resumable=False,  # Disable resumable for small metadata files to prevent corruption
                chunksize=DRIVE_CHUNK_SIZE
            )
            
            updated_file = service.files().update(
                fileId=file_id,
                media_body=media
            ).execute()
            
            log(f"[OK] Update thanh cong!")
            return file_id
            
        log(f"[i] File '{file_name}' da ton tai, bo qua upload")
        return file_id
    
    # Upload file mới
    file_size = os.path.getsize(file_path)
    log(f"[+] Uploading {file_name} ({format_size(file_size)})...")
    
    meta = {'name': file_name, 'parents': [folder_id]}
    if mimetype is None:
        if file_path.endswith('.apk'):
            mimetype = 'application/vnd.android.package-archive'
        elif file_path.endswith('.md'):
            mimetype = 'text/markdown'
        elif file_path.endswith('.json'):
            mimetype = 'application/json'
    
    # Use resumable only for large files (like APK)
    is_resumable = False # Disable resumable to avoid 'NoneType' object has no attribute 'size' error
    
    media = MediaFileUpload(
        file_path,
        mimetype=mimetype,
        resumable=is_resumable,
        chunksize=DRIVE_CHUNK_SIZE
    )
    
    request = service.files().create(body=meta, media_body=media, fields='id')
    
    if not is_resumable:
        response = request.execute()
    else:
        response = None
        retry_count = 0
        while response is None:
            try:
                status, response = request.next_chunk()
                if status:
                    progress = int(status.progress() * 100)
                    log(f"  Progress: {progress}%")
                    retry_count = 0
            except HttpError as e:
                retry_count += 1
                if retry_count > MAX_UPLOAD_RETRIES:
                    raise
                sleep_for = RETRY_BACKOFF_BASE ** retry_count
                log(f"[!] HttpError during upload: {e}. Retry {retry_count}/{MAX_UPLOAD_RETRIES} after {sleep_for}s")
                time.sleep(sleep_for)
                continue
            except Exception as e:
                retry_count += 1
                if retry_count > MAX_UPLOAD_RETRIES:
                    raise
                sleep_for = RETRY_BACKOFF_BASE ** retry_count
                log(f"[!] Error during upload: {e}. Retry {retry_count}/{MAX_UPLOAD_RETRIES} after {sleep_for}s")
                time.sleep(sleep_for)
                continue
    
    file_id = response.get('id')
    log(f"[OK] Upload thanh cong! (ID: {file_id})")
    return file_id

def set_file_public(service, file_id):
    """Đặt file thành public để có thể tải về"""
    try:
        service.permissions().create(
            fileId=file_id,
            body={'type': 'anyone', 'role': 'reader'}
        ).execute()
        log(f"[OK] Da dat quyen public cho file (ID: {file_id})")
    except Exception as e:
        log(f"[!] Khong the dat quyen public: {e}")

def create_metadata_json(version, version_code, apk_file_id, release_notes):
    """Tạo file metadata.json"""
    metadata = {
        "versionName": version,
        "versionCode": version_code,
        "downloadUrl": f"https://drive.google.com/uc?export=download&id={apk_file_id}",
        "changelog": release_notes[:500] + "..." if len(release_notes) > 500 else release_notes,
        "publishedAt": datetime.now().isoformat() + "Z",
        "fileSize": format_size(os.path.getsize(APK_PATH))
    }
    return json.dumps(metadata, indent=2, ensure_ascii=False)

def upload_to_drive(version):
    """Upload APK và các file liên quan lên Drive"""
    try:
        log("\n[+] Ket noi Google Drive...")
        service = get_drive_service()
        
        # Tạo hoặc tìm thư mục version
        version_folder_id = find_or_create_folder(
            service, version, DRIVE_PARENT_FOLDER_ID
        )
        
        # Upload APK
        import time
        timestamp = str(int(time.time()))
        apk_name = f'overtime_{version}_{timestamp}.apk'
        apk_file_id = upload_file(
            service, APK_PATH, apk_name, version_folder_id
        )
        set_file_public(service, apk_file_id)
        apk_download_url = f"https://drive.google.com/uc?export=download&id={apk_file_id}"
        
        # Tạo và upload README
        release_notes = get_release_notes(version)
        readme_path = f'tool/temp_readme_{version}.md'
        with open(readme_path, 'w', encoding='utf-8') as f:
            f.write(release_notes)
        
        readme_file_id = upload_file(
            service, readme_path, 'README.md', version_folder_id
        )
        set_file_public(service, readme_file_id)
        
        # Tạo và upload metadata.json
        metadata_content = create_metadata_json(
            version, get_version_code(), apk_file_id, release_notes
        )
        # Verify JSON content before saving and uploading
        try:
            json.loads(metadata_content)
        except Exception as e:
            raise Exception(f"Generated metadata is not valid JSON: {e}")

        metadata_path = f'tool/temp_metadata_{version}.json'
        with open(metadata_path, 'w', encoding='utf-8') as f:
            f.write(metadata_content)
        
        metadata_file_id = upload_file(
            service, metadata_path, 'metadata.json', version_folder_id
        )
        set_file_public(service, metadata_file_id)
        
        # Upload metadata.json vào root folder để app dễ check
        root_metadata_file_id = upload_file(
            service, metadata_path, 'latest_metadata.json', DRIVE_PARENT_FOLDER_ID
        )
        set_file_public(service, root_metadata_file_id)
        
        # Tự động cập nhật METADATA_FILE_ID trong code app
        update_metadata_file_id_in_code(root_metadata_file_id)
        
        # Cleanup temp files
        if os.path.exists(readme_path):
            os.remove(readme_path)
        if os.path.exists(metadata_path):
            os.remove(metadata_path)
        
        log("\n" + "="*60)
        log("HOAN TAT!")
        log("="*60)
        log(f"Version: {version}")
        log(f"APK Download: {apk_download_url}")
        log(f"Folder Drive: https://drive.google.com/drive/folders/{version_folder_id}")
        log(f"Metadata ID: {root_metadata_file_id}")
        log(f"Metadata URL: https://drive.google.com/uc?export=download&id={root_metadata_file_id}")
        log("="*60)
        log("\n[!] LUU Y: METADATA_FILE_ID da duoc tu dong cap nhat trong update_service.dart")
        log("   Ban can BUILD LAI APK va DEPLOY lai de app co the tu dong check update!")
        log("   Hoac giu nguyen File ID nay cho cac lan deploy sau.")
        log("="*60)
        
        return {
            'success': True,
            'apk_url': apk_download_url,
            'folder_id': version_folder_id,
            'metadata_file_id': root_metadata_file_id
        }
        
    except Exception as e:
        log(f"\n[X] Loi: {e}")
        import traceback
        traceback.print_exc()
        return {'success': False, 'error': str(e)}

# === MAIN ===

def main():
    print("="*60)
    print("OVER TIME - DEPLOY TO GOOGLE DRIVE")
    print("="*60)

    version = get_version()
    version_code = get_version_code()
    print(f"[i] Version: {version} (Build: {version_code})")

    # Tự động build APK nếu chưa có
    if not os.path.exists(APK_PATH):
        print(f"\n[!] APK chua duoc build tai: {APK_PATH}")
        print("[+] Tu dong build APK...")
        if not build_apk():
            print("[X] Build that bai!")
            return

    result = upload_to_drive(version)

    if result['success']:
        print("\n[OK] Deploy thanh cong!")
        print("\n" + "="*60)
        print("APP CUA BAN SE TU DONG CHECK UPDATE!")
        print("="*60)
        print("Tu bay gio, app se tu dong phat hien phien ban moi")
        print("Nguoi dung chi can mo app va nhan 'Kiem tra cap nhat'")
        print("="*60)
    else:
        print(f"\n[X] Deploy that bai: {result.get('error', 'Unknown error')}")
        sys.exit(1)

if __name__ == '__main__':
    main()
