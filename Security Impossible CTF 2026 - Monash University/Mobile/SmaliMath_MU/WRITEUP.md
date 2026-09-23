# SmaliMath_MU (Security Impossible CTF 2026 - Monash University, mobile)

The challenge supplies an Android package named `MathLock.apk`. The app locks access to a secure document behind a key check. Inspecting the decompiled Java code shows that the developer used DexGuard or custom bytecode routines that decompilers struggle to present cleanly in high-level Java, requiring us to audit the Dalvik Smali bytecode directly.

## Disassembling Smali Bytecode

Using `apktool`, we disassemble the APK into Dalvik intermediate representation:

```bash
apktool d -f MathLock.apk -o mathlock_src
```

Searching the Smali classes identifies `mathlock_src/smali/com/nightjar/mathlock/Crypto.smali`. We locate the primary decryption routine `reveal()`:

```smali
.method public static reveal()Ljava/lang/String;
    .registers 8

    const-string v0, "HVsCHx7qTQZSRFwC8Fe0HBV17BoMIk01En0e5Tj4piLgZeb9I/GX"
    const/4 v1, 0x0
    invoke-static {v0, v1}, Landroid/util/Base64;->decode(Ljava/lang/String;I)[B
    move-result-object v0

    const-string v2, "n1ghtj4r"
    invoke-virtual {v2}, Ljava/lang/String;->getBytes()[B
    move-result-object v2

    array-length v3, v0
    new-array v4, v3, [B

    const/4 v5, 0x0
    :goto_loop
    if-ge v5, v3, :cond_done

    aget-byte v6, v0, v5
    rem-int/lit8 v7, v5, 0x8
    aget-byte v7, v2, v7
    xor-int/2addr v6, v7
    sub-int/2addr v6, v5
    int-to-byte v6, v6
    aput-byte v6, v4, v5

    add-int/lit8 v5, v5, 0x1
    goto :goto_loop

    :cond_done
    new-instance v0, Ljava/lang/String;
    invoke-direct {v0, v4}, Ljava/lang/String;-><init>([B)V
    return-object v0
.end method
```

## Reversing the Arithmetic Transformation

Analyzing the Smali instructions step by step:
1. `Base64.decode`: Base64-decodes the string `"HVsCHx7qTQZSRFwC8Fe0HBV17BoMIk01En0e5Tj4piLgZeb9I/GX"`.
2. `v2`: Loads the 8-byte ASCII key `"n1ghtj4r"`.
3. In the loop (`:goto_loop`):
   - `aget-byte v6, v0, v5`: Fetches byte `data[i]`.
   - `rem-int/lit8 v7, v5, 0x8`: Computes `i % 8`.
   - `aget-byte v7, v2, v7`: Loads `key[i % 8]`.
   - `xor-int/2addr v6, v7`: Computes `data[i] ^ key[i % 8]`.
   - `sub-int/2addr v6, v5`: Computes `(data[i] ^ key[i % 8]) - i`.
   - `int-to-byte v6, v6`: Truncates to signed 8-bit byte.

## Python Implementation

We reproduce the arithmetic logic in Python:

```python
import base64

b64_str = "HVsCHx7qTQZSRFwC8Fe0HBV17BoMIk01En0e5Tj4piLgZeb9I/GX"
data = base64.b64decode(b64_str)
key = b"n1ghtj4r"

flag = bytes(((data[i] ^ key[i % 8]) - i) & 0xFF for i in range(len(data)))
print(flag.decode())
```

Running the script outputs the decrypted flag string.

Solve: `solve/solve.py`

Flag: `sictf{sm4l1_x0r_k3y_d3c0d3_r0ut1n3_r3v}`
