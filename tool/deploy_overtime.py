"""
Deploy APK to GitHub Releases
Script để build APK và upload lên GitHub Releases tự động
"""

import os
import sys
import yaml
import json
import subprocess
from datetime import datetime
import time
import requests

# === CONFIGURATION ===
PUBSPEC_PATH = 'pubspec.yaml'
APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
RELEASE_NOTES_DIR = 'release_notes'
METADATA_PATH = 'metadata.json'

# GitHub Config
GITHUB_REPO = 'ANHDOO/OverTime_Master'
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN') or '' 
if not GITHUB_TOKEN and os.path.exists('tool/.github_token'):
    with open('tool/.github_token', 'r') as f:
        GITHUB_TOKEN = f.read().strip()

# === UTILS ===

def log(message):
    print(message)

def format_size(bytes):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes < 1024:
            return f"{bytes:.1f}{unit}"
        bytes /= 1024
    return f"{bytes:.1f}TB"

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
    
    return f"""# OverTime v{version}
- **Version:** {version}
- **Build:** {get_version_code()}
- **Ngày phát hành:** {datetime.now().strftime('%d/%m/%Y')}

## Tinh năng moi
- Cải thiện hiệu suất và ổn định
- Sửa lỗi nhỏ
"""

def build_apk():
    """Build APK release"""
    log("\n[+] Building APK...")
    try:
        subprocess.run(['flutter', 'clean'], check=True, shell=True)
        result = subprocess.run(
            ['flutter', 'build', 'apk', '--target-platform', 'android-arm64', '--release'],
            check=True,
            shell=True
        )
        if result.returncode != 0:
            raise Exception(f"Build failed: {result.stderr}")
        log("[OK] Build thanh cong!")
        return True
    except Exception as e:
        log(f"[X] Build error: {e}")
        return False

# === GITHUB FUNCTIONS ===

def push_metadata_to_github(metadata_dict):
    """Đẩy file metadata.json lên GitHub bằng Content API (Zero-Touch)"""
    if not GITHUB_TOKEN:
        return False

    log(f"\n[+] Dang tu dong day metadata.json len GitHub...")
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    url = f"https://api.github.com/repos/{GITHUB_REPO}/contents/{METADATA_PATH}"
    
    # 1. Lấy SHA của file cũ (nếu có) để có thể ghi đè
    sha = None
    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        sha = response.json().get('sha')
    
    # 2. Upload/Update file
    import base64
    content_str = json.dumps(metadata_dict, indent=2, ensure_ascii=False)
    content_base64 = base64.b64encode(content_str.encode('utf-8')).decode('utf-8')
    
    data = {
        "message": f"🤖 Auto-update metadata for v{metadata_dict['versionName']}",
        "content": content_base64,
        "branch": "main" # Hoặc branch mặc định của bạn
    }
    
    if sha:
        data["sha"] = sha
        
    res = requests.put(url, headers=headers, json=data)
    
    if res.status_code in [200, 201]:
        log("[OK] Da cap nhat metadata.json len GitHub thanh cong!")
        return True
    else:
        log(f"[X] Khong the day metadata len GitHub: {res.status_code} - {res.text}")
        return False

def deploy_to_github(version, apk_path, release_notes):
    """Tạo GitHub Release và upload APK"""
    if not GITHUB_TOKEN:
        log("\n[!] GITHUB_TOKEN chua duoc cau hinh!")
        log("    Vui long tao token tai https://github.com/settings/tokens (quyen repo)")
        log("    va luu vao file 'tool/.github_token'.")
        return None

    log(f"\n[+] Dang tao GitHub Release cho v{version}...")
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }

    # 1. Tạo Release
    url = f"https://api.github.com/repos/{GITHUB_REPO}/releases"
    data = {
        "tag_name": f"v{version}",
        "name": f"v{version} - {datetime.now().strftime('%d/%m/%Y')}",
        "body": release_notes,
        "draft": False,
        "prerelease": False
    }

    response = requests.post(url, headers=headers, json=data)
    
    if response.status_code == 422: # Tag already exists
        log(f"[i] Release v{version} da ton tai, dang lay thong tin...")
        response = requests.get(f"{url}/tags/v{version}", headers=headers)
    
    if response.status_code not in [200, 201]:
        log(f"[X] Khong the tao/lay Release: {response.status_code} - {response.text}")
        return None

    release_data = response.json()
    release_id = release_data['id']
    upload_url = release_data['upload_url'].split('{')[0]
    
    # Kiem tra xem asset da ton tai chua
    assets_url = f"{url}/{release_id}/assets"
    assets_res = requests.get(assets_url, headers=headers)
    if assets_res.status_code == 200:
        for asset in assets_res.json():
            if asset['name'] == f'overtime_{version}.apk':
                log(f"[i] File APK da ton tai tren GitHub Release. Dang xoa de upload lai...")
                requests.delete(f"https://api.github.com/repos/{GITHUB_REPO}/releases/assets/{asset['id']}", headers=headers)

    # 2. Upload APK
    log(f"[+] Dang upload APK len GitHub Release...")
    with open(apk_path, 'rb') as f:
        upload_response = requests.post(
            f"{upload_url}?name=overtime_{version}.apk",
            headers={
                **headers,
                "Content-Type": "application/vnd.android.package-archive"
            },
            data=f
        )

    if upload_response.status_code not in [200, 201]:
        log(f"[X] Khong the upload APK len GitHub: {upload_response.text}")
        return None

    asset_data = upload_response.json()
    download_url = asset_data['browser_download_url']
    log(f"[OK] Upload len GitHub thanh cong: {download_url}")
    return download_url

def create_metadata_json(version, version_code, apk_url, release_notes):
    """Tạo hoặc cập nhật file metadata.json cục bộ"""
    metadata = {
        "versionName": version,
        "versionCode": version_code,
        "downloadUrl": apk_url,
        "changelog": release_notes[:500] + "..." if len(release_notes) > 500 else release_notes,
        "publishedAt": datetime.now().isoformat() + "Z",
        "fileSize": format_size(os.path.getsize(APK_PATH))
    }
    
    with open(METADATA_PATH, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    log(f"[OK] Da cap nhat {METADATA_PATH}")
    return metadata

# === MAIN ===

def main():
    print("="*60)
    print("OVER TIME - DEPLOY TO GITHUB RELEASES")
    print("="*60)

    version = get_version()
    version_code = get_version_code()
    print(f"[i] Version: {version} (Build: {version_code})")

    # Tự động build APK nếu chưa có
    if not os.path.exists(APK_PATH):
        if not build_apk():
            sys.exit(1)
    else:
        # Hoi xem co muon build lai khong
        log(f"[i] Tim thay file APK tai: {APK_PATH}")
        choice = input("[?] Ban co muon build lai APK moi khong? (y/N): ")
        if choice.lower() == 'y':
            if not build_apk():
                sys.exit(1)

    release_notes = get_release_notes(version)
    github_apk_url = deploy_to_github(version, APK_PATH, release_notes)

    if github_apk_url:
        metadata = create_metadata_json(version, version_code, github_apk_url, release_notes)
        
        # TỰ ĐỘNG PUSH METADATA LÊN GITHUB
        push_metadata_to_github(metadata)
        
        print("\n" + "="*60)
        print("DEPLOY THANH CONG!")
        print("="*60)
        print(f"Version: {version}")
        print(f"GitHub URL: {github_apk_url}")
        print("-" * 60)
        print("[i] He thong da tu dong cap nhat metadata.json len repo.")
        print("    App cua ban da co the nhan thay ban cap nhat moi ngay lap tuc!")
        print("="*60)
    else:
        print("\n[X] Deploy that bai!")
        sys.exit(1)

if __name__ == '__main__':
    main()
