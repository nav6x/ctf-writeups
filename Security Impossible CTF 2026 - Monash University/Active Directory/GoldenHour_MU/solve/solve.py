import hashlib

ct = bytes.fromhex("a66bdd170a757735c80a0a0226b023fd1be41f20d71fde7cf3e615c8e43ccfd3a65dcd160e642532df04")
key = hashlib.sha256(b"esc1|WebServer-Legacy-Auth").digest()
print(bytes(ct[i] ^ key[i % 32] for i in range(len(ct))).decode())
