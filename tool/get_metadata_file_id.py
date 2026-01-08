"""
Script để lấy File ID của latest_metadata.json từ Google Drive
và tự động cập nhật vào update_service.dart

Usage:
    python tool/get_metadata_file_id.py
"""

import os
import pickle
import re
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Configuration
DRIVE_CREDENTIALS_FILE = 'tool/credentials.json'
DRIVE_TOKEN_FILE = 'tool/token.pickle'
DRIVE_PARENT_FOLDER_ID = '1NjHCrZyZohQnRptgZL62G7LUTEFL66YY'
DRIVE_SCOPES = ['https://www.googleapis.com/auth/drive.file']
UPDATE_SERVICE_PATH = 'lib/services/update_service.dart'

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
                raise Exception(f"Khong tim thay {DRIVE_CREDENTIALS_FILE}")
            flow = InstalledAppFlow.from_client_secrets_file(
                DRIVE_CREDENTIALS_FILE, DRIVE_SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(DRIVE_TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)
    
    return build('drive', 'v3', credentials=creds)

def find_metadata_file(service):
    """Tìm file latest_metadata.json trong folder root"""
    query = f"name = 'latest_metadata.json' and '{DRIVE_PARENT_FOLDER_ID}' in parents and trashed = false"
    res = service.files().list(q=query, fields="files(id, name, modifiedTime)").execute()
    files = res.get('files', [])
    
    if files:
        return files[0]
    return None

def update_metadata_file_id_in_code(file_id):
    """Cap nhat METADATA_FILE_ID trong update_service.dart"""
    if not os.path.exists(UPDATE_SERVICE_PATH):
        print(f"[!] Khong tim thay file {UPDATE_SERVICE_PATH}")
        return False
    
    try:
        with open(UPDATE_SERVICE_PATH, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Tim METADATA_FILE_ID hien tai
        match = re.search(r"static const String METADATA_FILE_ID = '([^']*)'", content)
        if match:
            current_id = match.group(1)
            print(f"[i] METADATA_FILE_ID hien tai trong code: {current_id}")
            
            if current_id == file_id:
                print("[OK] File ID da dung, khong can cap nhat!")
                return True
        
        # Thay the METADATA_FILE_ID
        old_pattern = r"static const String METADATA_FILE_ID = '[^']*';"
        new_value = f"static const String METADATA_FILE_ID = '{file_id}';"
        
        if re.search(old_pattern, content):
            new_content = re.sub(old_pattern, new_value, content)
            
            with open(UPDATE_SERVICE_PATH, 'w', encoding='utf-8') as f:
                f.write(new_content)
            
            print(f"[OK] Da cap nhat METADATA_FILE_ID = '{file_id}' trong update_service.dart")
            return True
        else:
            print(f"[!] Khong tim thay METADATA_FILE_ID trong {UPDATE_SERVICE_PATH}")
            return False
    except Exception as e:
        print(f"[X] Loi khi cap nhat METADATA_FILE_ID: {e}")
        return False

def main():
    print("="*60)
    print("[*] TIM VA CAP NHAT METADATA FILE ID")
    print("="*60)
    
    try:
        print("\n[+] Ket noi Google Drive...")
        service = get_drive_service()
        
        print(f"[+] Tim file latest_metadata.json trong folder root...")
        metadata_file = find_metadata_file(service)
        
        if metadata_file:
            file_id = metadata_file['id']
            print(f"\n[OK] Tim thay file latest_metadata.json!")
            print(f"   - File ID: {file_id}")
            print(f"   - Modified: {metadata_file.get('modifiedTime', 'N/A')}")
            print(f"   - URL: https://drive.google.com/uc?export=download&id={file_id}")
            
            # Hoi co muon cap nhat khong
            choice = input("\n[?] Ban co muon cap nhat File ID vao update_service.dart? (y/n): ")
            if choice.lower() == 'y':
                update_metadata_file_id_in_code(file_id)
                print("\n[!] LUU Y: Ban can BUILD LAI APK de app co File ID moi!")
            else:
                print("\n[i] Ban co the cap nhat thu cong:")
                print(f"   Mo file: lib/services/update_service.dart")
                print(f"   Thay doi: METADATA_FILE_ID = '{file_id}'")
        else:
            print("\n[X] Khong tim thay file latest_metadata.json trong folder root!")
            print("   Vui long chay deploy truoc: python tool/deploy_overtime.py")
            
    except Exception as e:
        print(f"\n[X] Loi: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()

