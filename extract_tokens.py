import pickle
import json
import os

f_token = 'tool/sheets_token.pickle'
f_creds = 'tool/credentials.json'

with open('temp_tokens.txt', 'w', encoding='utf-8') as f_out:
    if os.path.exists(f_token):
        with open(f_token, 'rb') as f:
            creds = pickle.load(f)
            f_out.write(f"ACCESS TOKEN: {creds.token}\n")
            f_out.write(f"REFRESH TOKEN: {getattr(creds, 'refresh_token', 'N/A')}\n")
    else:
        f_out.write("ACCESS TOKEN: N/A\n")
        f_out.write("REFRESH TOKEN: N/A\n")

    if os.path.exists(f_creds):
        with open(f_creds, 'r') as f:
            data = json.load(f)
            clients = data.get('installed') or data.get('web') or {}
            f_out.write(f"CLIENT ID: {clients.get('client_id', 'N/A')}\n")
            f_out.write(f"CLIENT SECRET: {clients.get('client_secret', 'N/A')}\n")
    else:
        f_out.write("CLIENT ID: N/A\n")
        f_out.write("CLIENT SECRET: N/A\n")

print("Done writing to temp_tokens.txt")
