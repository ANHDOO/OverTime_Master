import requests
import json

url = "https://drive.google.com/uc?export=download&id=17HnOQ3CKafJ6IF4H_KIMerxpo8-Lrzuw"
response = requests.get(url)

print(f"Status Code: {response.status_code}")
print("Response Body:")
print(response.text)

try:
    data = json.loads(response.text)
    print("\nParsed JSON:")
    print(json.dumps(data, indent=2))
except Exception as e:
    print(f"\nFailed to parse JSON: {e}")
