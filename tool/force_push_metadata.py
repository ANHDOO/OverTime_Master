import requests
import json
import base64
import os

repo = 'ANHDOO/OverTime_Updates'
path = 'metadata.json'
token = ''
if os.path.exists('tool/.github_token'):
    with open('tool/.github_token', 'r') as f:
        token = f.read().strip()

headers = {
    'Authorization': f'token {token}',
    'Accept': 'application/vnd.github.v3+json'
}

url = f'https://api.github.com/repos/{repo}/contents/{path}'

# 1. Get SHA
res = requests.get(url, headers=headers)
sha = res.json().get('sha') if res.status_code == 200 else None

# 2. Read local metadata
with open('metadata.json', 'r', encoding='utf-8') as f:
    content = f.read()

# 3. Push
data = {
    'message': 'Force update metadata v1.4.2 (Manual Fix)',
    'content': base64.b64encode(content.encode('utf-8')).decode('utf-8'),
    'branch': 'main'
}
if sha:
    data['sha'] = sha

r = requests.put(url, headers=headers, json=data)
print(f'Status: {r.status_code}')
print(f'Response: {r.text}')
