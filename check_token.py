import urllib.request, json, sys

# Paste the token (user-provided). Only the token string (no trailing text).
token = "ya29.a0Aa7pCA8wQkSRUXp0Wxnpf2JwWfyxcwLr00q3eX31vmPxc8F-Dso3gE0roiXkEWqRH7pBm6pqZTKptyQFnePJNLEAQzyws7iycrxUgdJzkryTUJ1-GasZEQRHkMvGSrPEZbSsxu98jo-v1s7m1QZvNXh8jwh-JQ7kkbxNkGcHVD26x-gSkjAetY6cy-cWhjYbUYg3J-AaCgYKAcQSARISFQHGX2MixRpmfU2UcdASjTqxt3eMIA0206"

url = f"https://oauth2.googleapis.com/tokeninfo?access_token={token}"

try:
    with urllib.request.urlopen(url, timeout=15) as resp:
        data = json.load(resp)
        print(json.dumps(data, indent=2, ensure_ascii=False))
except urllib.error.HTTPError as e:
    try:
        err = e.read().decode()
        print(f"HTTPError {e.code}: {err}")
    except:
        print(f"HTTPError {e.code}")
except Exception as ex:
    print(f"Error: {ex}")




