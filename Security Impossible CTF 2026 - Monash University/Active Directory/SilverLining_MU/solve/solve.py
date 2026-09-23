import hashlib

ct = bytes.fromhex("a8a02f48b73a7471933ea4bf059742a325872c2510b072696cce43c9f3ee9395eaf92263b5757a")
key = hashlib.sha256(b"s4u|svc-webapp01").digest()
print(bytes(ct[i] ^ key[i % 32] for i in range(len(ct))).decode())
