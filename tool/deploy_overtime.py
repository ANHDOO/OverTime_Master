"""
Deploy APK to GitHub Releases
Script để build APK và upload lên GitHub Releases tự động

Usage:
    python deploy_overtime.py          # Full deploy (check + build + upload)
    python deploy_overtime.py --check  # Only run flutter analyze (quick check)
    python deploy_overtime.py --build  # Only build, skip check and upload
"""

import os
import sys
import yaml
import json
import subprocess
from datetime import datetime
import time
import requests
import base64
import argparse

# === CONFIGURATION ===
PUBSPEC_PATH = 'pubspec.yaml'
APK_PATH = 'build/app/outputs/flutter-apk/app-release.apk'
RELEASE_NOTES_DIR = 'release_notes'
METADATA_PATH = 'metadata.json'

# GitHub Config
GITHUB_REPO = 'ANHDOO/OverTime_Master'        # Main repo for source code + releases
UPDATES_REPO = 'ANHDOO/OverTime_Updates'       # Separate public repo for metadata.json
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

## Tính năng mới
- Cải thiện hiệu suất và ổn định
- Sửa lỗi nhỏ
"""


# === CHECK MODE ===

def run_flutter_analyze():
    """Chạy flutter analyze và trả về True nếu không có lỗi"""
    log("\n" + "="*60)
    log("FLUTTER ANALYZE - Kiểm tra lỗi")
    log("="*60)
    
    log("[+] Đang chạy flutter analyze...")
    
    result = subprocess.run(
        ['flutter', 'analyze'],
        capture_output=True,
        text=True,
        shell=True
    )
    
    # Ensure we have strings even if output is None
    stdout = result.stdout or ""
    stderr = result.stderr or ""

    # In kết quả
    if stdout:
        log(stdout)
    if stderr:
        log(stderr)
    
    # Đếm số lỗi và warning - sử dụng pattern chính xác
    # Flutter analyze format: "severity - message - file:line - code"
    import re
    error_matches = re.findall(r'^\s*error\s+-', stdout, re.MULTILINE | re.IGNORECASE)
    warning_matches = re.findall(r'^\s*warning\s+-', stdout, re.MULTILINE | re.IGNORECASE)
    info_matches = re.findall(r'^\s*info\s+-', stdout, re.MULTILINE | re.IGNORECASE)
    
    error_count = len(error_matches)
    warning_count = len(warning_matches)
    info_count = len(info_matches)
    
    log("\n" + "-"*60)
    log(f"Kết quả: {error_count} errors, {warning_count} warnings, {info_count} infos")
    
    if error_count > 0:
        log("[X] Có LỖI cần sửa trước khi build!")
        return False
    elif warning_count > 0:
        log("[!] Có warnings nhưng không block build")
        return True
    else:
        log("[OK] Không có lỗi!")
        return True


# === BUILD ===

def should_skip_build():
    """Kiểm tra xem file APK hiện tại có mới hơn source code không"""
    if not os.path.exists(APK_PATH):
        return False
    
    apk_mtime = os.path.getmtime(APK_PATH)
    
    # Kiểm tra pubspec.yaml và thư mục lib
    source_paths = [PUBSPEC_PATH, 'lib']
    for p in source_paths:
        if os.path.isfile(p):
            if os.path.getmtime(p) > apk_mtime:
                return False
        else:
            for root, dirs, files in os.walk(p):
                for f in files:
                    if f.endswith('.dart'):
                        if os.path.getmtime(os.path.join(root, f)) > apk_mtime:
                            return False
    return True

def build_apk():
    """Build APK release"""
    if should_skip_build():
        log("\n[i] APK hien tai da moi nhat. Bo qua buoc build de tiet kiem thoi gian.")
        return True

    log("\n[+] Building APK...")
    try:
        # User co 32GB RAM, chung ta se bo qua flutter clean de tan dung cache
        # Neu muon clean, hay chay manual truoc.
        
        result = subprocess.run(
            ['flutter', 'build', 'apk', 
             '--target-platform', 'android-arm64', 
             '--release',
             '--no-pub'], # Bo qua pub get vi da check ben ngoai
            check=True,
            shell=True
        )
        if result.returncode != 0:
            raise Exception(f"Build failed: {result.stderr}")
        log("[OK] Build thanh cong!")
        
        # Dọn dẹp RAM: Kill các process Java/Gradle sau khi build xong
        cleanup_gradle_processes()
        
        return True
    except Exception as e:
        log(f"[X] Build that bai: {e}")
        cleanup_gradle_processes()
        return False


def cleanup_gradle_processes():
    """Dọn dẹp các process Gradle/Java để giải phóng RAM"""
    log("\n[+] Dang don dep Gradle/Java processes...")
    try:
        if sys.platform == 'win32':
            # Windows
            subprocess.run(['taskkill', '/F', '/IM', 'java.exe'], 
                         capture_output=True, shell=True)
            subprocess.run(['taskkill', '/F', '/IM', 'gradle.exe'], 
                         capture_output=True, shell=True)
        else:
            # Linux/Mac
            subprocess.run(['pkill', '-f', 'java'], capture_output=True)
            subprocess.run(['pkill', '-f', 'gradle'], capture_output=True)
        log("[OK] Da giai phong RAM (killed Gradle/Java processes)")
    except Exception as e:
        log(f"[!] Khong the don dep: {e}")


# === GITHUB FUNCTIONS ===

def push_metadata_to_github(metadata_dict):
    """Đẩy file metadata.json lên CÁCH repo GitHub (cả repo cũ và mới để backward compatible)"""
    if not GITHUB_TOKEN:
        log("[!] GITHUB_TOKEN chưa được cấu hình, bỏ qua push metadata")
        return False

    log(f"\n[+] Đang push metadata.json (Build {metadata_dict['versionCode']}) lên GitHub...")
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    # Chỉ push lên repo OverTime_Updates (repo riêng cho updates)
    repos_to_push = [
        UPDATES_REPO,   # Repo mới cho updates (public)
    ]
    
    success = True
    for repo in repos_to_push:
        url = f"https://api.github.com/repos/{repo}/contents/{METADATA_PATH}"
        
        # 1. Lấy SHA của file hiện tại (nếu có)
        sha = None
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            sha = response.json().get('sha')
        
        # 2. Chuẩn bị content
        content_str = json.dumps(metadata_dict, indent=2, ensure_ascii=False)
        content_base64 = base64.b64encode(content_str.encode('utf-8')).decode('utf-8')
        
        # 3. Tạo commit message
        version_name = metadata_dict['versionName']
        version_code = metadata_dict['versionCode']
        commit_msg = f"📦 Update metadata v{version_name} (Build {version_code})"
        
        # 4. Push lên GitHub
        data = {
            "message": commit_msg,
            "content": content_base64,
            "branch": "main"
        }
        
        if sha:
            data["sha"] = sha
            
        res = requests.put(url, headers=headers, json=data)
        
        if res.status_code in [200, 201]:
            log(f"[OK] Đã push metadata → {repo}")
        else:
            log(f"[X] Không thể push → {repo}: {res.status_code}")
            success = False
    
    return success


def deploy_to_github(version, apk_path, release_notes):
    """Tạo GitHub Release và upload APK"""
    if not GITHUB_TOKEN:
        log("\n[!] GITHUB_TOKEN chua duoc cau hinh!")
        log("    Vui long tao token tai https://github.com/settings/tokens (quyen repo)")
        log("    va luu vao file 'tool/.github_token'.")
        return None

    log(f"\n[+] Dang deploy len GitHub Releases...")
    
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    
    # 1. Check if release exists
    tag_name = f"v{version}"
    releases_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/tags/{tag_name}"
    
    response = requests.get(releases_url, headers=headers)
    
    if response.status_code == 200:
        # Release exists - update it
        release_data = response.json()
        release_id = release_data['id']
        log(f"[i] Release {tag_name} da ton tai, dang cap nhat...")
        
        # Delete old asset if exists
        for asset in release_data.get('assets', []):
            if asset['name'].endswith('.apk'):
                delete_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/assets/{asset['id']}"
                requests.delete(delete_url, headers=headers)
                log(f"[i] Da xoa APK cu: {asset['name']}")
    else:
        # Create new release
        create_url = f"https://api.github.com/repos/{GITHUB_REPO}/releases"
        create_data = {
            "tag_name": tag_name,
            "name": f"OverTime v{version}",
            "body": release_notes,
            "draft": False,
            "prerelease": False
        }
        
        response = requests.post(create_url, headers=headers, json=create_data)
        if response.status_code != 201:
            log(f"[X] Khong the tao release: {response.status_code}")
            log(response.text)
            return None
            
        release_data = response.json()
        release_id = release_data['id']
        log(f"[OK] Da tao release moi: {tag_name}")
    
    # 2. Upload APK
    upload_url = f"https://uploads.github.com/repos/{GITHUB_REPO}/releases/{release_id}/assets?name=overtime_{version}.apk"
    
    with open(apk_path, 'rb') as f:
        apk_data = f.read()
    
    upload_headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
        "Content-Type": "application/vnd.android.package-archive"
    }
    
    log(f"[+] Dang upload APK ({format_size(len(apk_data))})...")
    response = requests.post(upload_url, headers=upload_headers, data=apk_data)
    
    if response.status_code != 201:
        log(f"[X] Upload APK that bai: {response.status_code}")
        log(response.text)
        return None
    
    asset_data = response.json()
    download_url = asset_data['browser_download_url']
    
    log(f"[OK] Upload len GitHub thanh cong: {download_url}")
    return download_url


def create_metadata_json(version, version_code, apk_url, release_notes):
    """Tạo metadata.json cho app update check (format giống Build 22)"""
    # Lấy file size của APK
    file_size = "21.0MB"
    try:
        apk_size = os.path.getsize(APK_PATH)
        file_size = f"{apk_size / (1024 * 1024):.1f}MB"
    except:
        pass
    
    metadata = {
        "versionName": version,
        "versionCode": version_code,
        "downloadUrl": apk_url,
        "changelog": release_notes,  # NOT escaped, full markdown
        "publishedAt": datetime.now().isoformat() + "Z",
        "fileSize": file_size
    }
    
    # Lưu local
    with open(METADATA_PATH, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    log(f"[OK] Da cap nhat metadata.json Release")
    return metadata


# === MAIN ===

def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description='Deploy OverTime APK to GitHub')
    parser.add_argument('--check', action='store_true', help='Chỉ chạy flutter analyze (không build)')
    parser.add_argument('--build', action='store_true', help='Chỉ build APK (không upload)')
    args = parser.parse_args()
    
    print("="*60)
    print("OVER TIME - DEPLOY TO GITHUB RELEASES")
    print("="*60)

    version = get_version()
    version_code = get_version_code()
    print(f"[i] Version: {version} (Build: {version_code})")

    # Check-only mode
    if args.check:
        success = run_flutter_analyze()
        if success:
            print("\n[OK] Kiểm tra hoàn tất! Có thể chạy: python deploy_overtime.py")
        else:
            print("\n[X] Có lỗi cần sửa!")
        sys.exit(0 if success else 1)
    
    # Build-only mode
    if args.build:
        if not build_apk():
            sys.exit(1)
        print(f"\n[OK] APK đã được build tại: {APK_PATH}")
        sys.exit(0)

    # Full deploy mode
    if not build_apk():
        sys.exit(1)

    release_notes = get_release_notes(version)
    github_apk_url = deploy_to_github(version, APK_PATH, release_notes)

    if github_apk_url:
        metadata = create_metadata_json(version, version_code, github_apk_url, release_notes)
        
        # Push metadata lên GitHub
        push_metadata_to_github(metadata)
        
        print("\n" + "="*60)
        print("DEPLOY THANH CONG!")
        print("="*60)
        print(f"Version: {version}")
        print(f"GitHub URL: {github_apk_url}")
        print("-" * 60)
        print("[i] Metadata đã được push lên GitHub.")
        print("    App sẽ nhận được thông báo cập nhật!")
        print("="*60)
    else:
        print("\n[X] Deploy that bai!")
        sys.exit(1)

if __name__ == '__main__':
    main()
