import base64

data = base64.b64decode("MSggPzMrOGA4cDBwIBRhPDMMZzAdJncmZg9vJWUxPw==")
key = b"BACKUP_SVC"
print(bytes(c ^ key[i % len(key)] for i, c in enumerate(data)).decode())
