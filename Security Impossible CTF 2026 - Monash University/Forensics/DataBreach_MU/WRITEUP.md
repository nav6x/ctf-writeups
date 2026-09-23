# DataBreach_MU (Security Impossible CTF 2026 - Monash University, forensics)

We are provided with a network packet capture file named `query_trace.pcap` containing 117 HTTP frames. The capture records traffic from an internal enterprise workstation at `10.20.4.37` that suffered a data exfiltration incident. Our goal is to reconstruct the exfiltration sequence, identify how the compromised host acquired its encryption keys, and decrypt the stolen payload.

## Packet Analysis and Host Timeline

Opening the capture in Wireshark or parsing it with `tshark` allows us to isolate the HTTP requests:

```bash
tshark -r query_trace.pcap -Y 'http.request' -T fields -e frame.number -e ip.dst -e http.host -e http.request.method -e http.request.uri
```

The timeline shows three distinct stages of activity from `10.20.4.37`:
1. **Intranet Reconnaissance**: The workstation performs ordinary `GET` requests against internal web resources.
2. **Keyring Query**: The workstation sends an HTTP `GET` request to `keyring.alloway.local` (internal IP `10.20.4.10`) requesting `/api/v1/config`.
3. **Data Exfiltration**: Immediately after receiving the keyring response, the workstation sends an HTTP `POST` request to an external IP `203.0.113.44` with the Host header `cdn-metrics-eu.example` targeting `/upload.php`.

## Dissecting the Crypto Configuration

We dump the HTTP response from `10.20.4.10`:

```bash
tshark -r query_trace.pcap -Y 'ip.src==10.20.4.10 and http.file_data' -T fields -e http.file_data
```

The server returns a JSON configuration:

```json
{
  "cipher": "AES-256-GCM",
  "kdf": "scrypt",
  "kdf_params": {
    "salt": "alloway",
    "n": 16384,
    "r": 8,
    "p": 1,
    "key_len": 32
  },
  "passphrase": "kr-7734-westbourne",
  "format": "base64(nonce[12] || ciphertext || tag[16])"
}
```

The exfiltration mechanism uses AES-256-GCM authenticated encryption. The 32-byte key is derived using scrypt from the passphrase `kr-7734-westbourne` and salt `alloway` with standard cost parameters ($N=16384, r=8, p=1$).

## Carving and Decrypting the Exfiltration Payload

Next, we extract the HTTP POST body sent to `cdn-metrics-eu.example/upload.php`:

```bash
tshark -r query_trace.pcap -Y 'http.request.method=="POST"' -T fields -e http.file_data
```

The request body contains URL-encoded form data with a single parameter:

```text
payload=a7F9mK...
```

An important detail here is URL decoding: in standard URL encoding, the plus character `+` represents a space. However, in standard Base64, `+` is a valid alphabet character. Blindly URL-decoding the entire body would convert legitimate Base64 `+` characters into spaces, corrupting the payload. We split the string directly on `payload=`, retain literal plus signs, and pad with `=` to ensure a multiple of 4 bytes.

Once decoded, the first 12 bytes provide the GCM initialization vector (nonce), the trailing 16 bytes represent the GCM authentication tag, and the intervening bytes are the ciphertext.

We assemble the Python decryption solver:

```python
import hashlib
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

passphrase = b"kr-7734-westbourne"
salt = b"alloway"
key = hashlib.scrypt(passphrase, salt=salt, n=16384, r=8, p=1, dklen=32)

payload_b64 = "1U2k3V...REDACTED_BASE64_STREAM..."
raw = base64.b64decode(payload_b64)
nonce = raw[:12]
tag = raw[-16:]
ct = raw[12:-16]

aesgcm = AESGCM(key)
pt = aesgcm.decrypt(nonce, ct + tag, None)
print(pt.decode())
```

Running the decryption script validates the authentication tag and recovers the flag.

Flag: `sictf{tw0_str34ms_k3y_th3n_c1ph3rt3xt}`
