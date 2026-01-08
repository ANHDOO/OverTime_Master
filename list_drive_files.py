import os
import pickle
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from googleapiclient.discovery import build

# Configuration
DRIVE_CREDENTIALS_FILE = 'tool/credentials.json'
DRIVE_TOKEN_FILE = 'tool/token.pickle'
DRIVE_PARENT_FOLDER_ID = '1K7ZLQLkBnWdQ45KBkHKf9emg_ak4bSDs'
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

def list_files():
    service = get_drive_service()
    # List all files in the parent folder
    query = f"'{DRIVE_PARENT_FOLDER_ID}' in parents and trashed = false"
    res = service.files().list(q=query, fields="files(id, name, mimeType)").execute()
    files = res.get('files', [])
    
    print(f"Files in folder {DRIVE_PARENT_FOLDER_ID}:")
    for f in files:
        print(f" - {f['name']} (ID: {f['id']}, Type: {f['mimeType']})")

if __name__ == '__main__':
    list_files()
