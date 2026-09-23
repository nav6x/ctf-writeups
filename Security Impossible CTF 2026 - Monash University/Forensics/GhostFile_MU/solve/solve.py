import base64
import hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

raw = base64.b64decode("Lno/wU1vOv2ojoHDouIY32wi8bR2OtmvKf7UCwR5HoHIvZ6XUXwSlUDoA25EadCl35YTbYi93qJioSuyZ4mW3XR6")
nonce, ct_tag = raw[:12], raw[12:]
key = hashlib.scrypt(b"nightjar-fieldkit-2026", salt=b"nightjar", n=16384, r=8, p=1, dklen=32)
print(AESGCM(key).decrypt(nonce, ct_tag, None).decode())
