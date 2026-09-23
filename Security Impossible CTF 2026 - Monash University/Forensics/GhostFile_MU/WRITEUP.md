# GhostFile_MU (Security Impossible CTF 2026 - Monash University, forensics)

The challenge supplies a raw 16 MB filesystem image named `usb_recovered.dd` acquired from a seized USB flash drive. Our objective is to perform forensic carving on unallocated blocks, recover a deleted confidential document, and decrypt the embedded secret.

## Filesystem Examination with The Sleuth Kit

Mounting the raw image directly reveals an empty directory tree with no user files. To inspect the underlying Linux ext filesystem structure, we employ The Sleuth Kit (TSK) tools.

Running `fls` with recursion (`-r`) displays all allocated and unallocated filesystem inodes:

```bash
fls -r usb_recovered.dd
```

The tool reports several deleted directory entries marked with an asterisk (`*`):
- Inode 12: `* d/d 12: lost+found`
- Inode 15: `* r/r 15: IMG_0042.jpg`
- Inode 17: `* r/r 17: notes.txt`

Inode 15 points to a deleted JPEG file whose directory metadata was orphaned when the user executed `rm`, but whose raw disk blocks remain intact in unallocated space.

## Carving the Artifacts

We extract the deleted files using `icat`:

```bash
icat usb_recovered.dd 17 > notes.txt
icat usb_recovered.dd 15 > IMG_0042.jpg
```

Reading `notes.txt` reveals operational field notes left by the suspect:
```text
Key derivation: scrypt with salt="nightjar", N=16384, r=8, p=1
Password hint: nightjar-fieldkit-2026
Format: AES-GCM-256
```

Next, we inspect the carved JPEG file `IMG_0042.jpg`. The image displays an ordinary outdoor landscape, but running `exiftool` exposes metadata stored within the JPEG Comment (`COM`) segment:

```bash
exiftool IMG_0042.jpg
```

Output:
```text
Comment: Lno/wU1vOv2ojoHDouIY32wi8bR2OtmvKf7UCwR5HoHIvZ6XUXwSlUDoA25EadCl35YTbYi93qJioSuyZ4mW3XR6
```

## Reversing the Cryptographic Container

The comment field holds a base64 encoded string. Decoding the 66-byte payload yields:
- 12-byte nonce
- 38 bytes of ciphertext
- 16-byte authentication tag

Using the parameters recovered from `notes.txt`, we derive the 32-byte key via scrypt and decrypt the ciphertext using AES-GCM:

```python
import base64
import hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

raw = base64.b64decode("Lno/wU1vOv2ojoHDouIY32wi8bR2OtmvKf7UCwR5HoHIvZ6XUXwSlUDoA25EadCl35YTbYi93qJioSuyZ4mW3XR6")
nonce, ct_tag = raw[:12], raw[12:]

key = hashlib.scrypt(
    b"nightjar-fieldkit-2026",
    salt=b"nightjar",
    n=16384,
    r=8,
    p=1,
    dklen=32
)

aesgcm = AESGCM(key)
flag = aesgcm.decrypt(nonce, ct_tag, None)
print(flag.decode())
```

The ciphertext decrypts cleanly, yielding the flag.

Solve: `solve/solve.py`

Flag: `sictf{unalloc_c4rv3_th3n_unwr4p_v4ult}`
