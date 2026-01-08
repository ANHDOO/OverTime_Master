import os
import pickle
import json
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

# Configuration from deploy_overtime.py
DRIVE_CREDENTIALS_FILE = 'tool/credentials.json'
DRIVE_TOKEN_FILE = 'tool/token.pickle'
DRIVE_PARENT_FOLDER_ID = '1NjHCrZyZohQnRptgZL62G7LUTEFL66YY'
DRIVE_SCOPES = ['https://www.googleapis.com/auth/drive.file']

def get_drive_service():
    creds = None
    if os.path.exists(DRIVE_TOKEN_FILE):
        with open(DRIVE_TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(DRIVE_CREDENTIALS_FILE, DRIVE_SCOPES)
            creds = flow.run_local_server(port=0)
        with open(DRIVE_TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)
    return build('drive', 'v3', credentials=creds)

def fix_metadata():
    service = get_drive_service()
    
    # Correct metadata content (Simulating a NEW version)
    metadata = {
      "versionName": "1.2.3",
      "versionCode": 2,
      "downloadUrl": "https://drive.google.com/uc?export=download&id=1S5N9tRy7CPgvRaxvmFpYKGBlLEJVmz2G",
      "changelog": "Bản cập nhật giả lập để kiểm tra tính năng tự động update:\n- Sửa lỗi UI treo khi check update\n- Cải thiện tốc độ tải dữ liệu",
      "publishedAt": "2026-01-08T17:10:00Z",
      "fileSize": "61.8MB"
    }
    
    metadata_content = json.dumps(metadata, indent=2, ensure_ascii=False)
    with open('tool/latest_metadata.json', 'w', encoding='utf-8') as f:
        f.write(metadata_content)
    
    # Find existing latest_metadata.json
    query = f"name = 'latest_metadata.json' and '{DRIVE_PARENT_FOLDER_ID}' in parents and trashed = false"
    res = service.files().list(q=query, fields="files(id)").execute()
    files = res.get('files', [])
    
    if files:
        file_id = files[0]['id']
        print(f"Updating file {file_id}...")
        media = MediaFileUpload('tool/latest_metadata.json', mimetype='application/json', resumable=False)
        service.files().update(fileId=file_id, media_body=media).execute()
        print("Successfully updated metadata on Drive.")
    else:
        print("latest_metadata.json not found on Drive.")

if __name__ == '__main__':
    fix_metadata()
