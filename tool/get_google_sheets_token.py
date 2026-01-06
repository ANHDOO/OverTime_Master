"""
Script để lấy Google Sheets API Access Token
Sử dụng OAuth 2.0 flow để lấy token cho app

Usage:
    python tool/get_google_sheets_token.py

Requirements:
    pip install google-auth-oauthlib google-api-python-client
"""

import os
import pickle
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

# Google Sheets API Scopes
SCOPES = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file'
]

CREDENTIALS_FILE = 'tool/credentials.json'
TOKEN_FILE = 'tool/sheets_token.pickle'

def get_access_token():
    """Lấy access token từ OAuth flow"""
    creds = None
    
    # Kiểm tra token đã lưu chưa
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)
    
    # Nếu không có token hoặc token hết hạn
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            # Refresh token
            creds.refresh(Request())
        else:
            # Chạy OAuth flow
            if not os.path.exists(CREDENTIALS_FILE):
                print(f"❌ Không tìm thấy {CREDENTIALS_FILE}")
                print("Vui lòng tải credentials.json từ Google Cloud Console")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(
                CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Lưu token
        with open(TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)
    
    print("="*60)
    print("✅ ACCESS TOKEN:")
    print("="*60)
    print(creds.token)
    print("="*60)
    print("\n📋 Copy token này và dán vào app trong Settings > Cấu hình Google Sheets")
    print("="*60)
    
    return creds.token

if __name__ == '__main__':
    get_access_token()
