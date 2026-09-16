# cryjail (K17 CTF, crypto)

The remote service presents an AES-CBC decryption interface wrapped in a sandboxed execution harness. It accepts `iv:ciphertext` in hex, decrypts it, embeds the resulting string inside a Python `b"..."` literal, and runs the generated script inside a restricted child process.

## The injection flaw

The server sanitizes the decrypted bytes using an `escape()` routine before inserting them into the template:

```python
def escape(s):
    ...
```

The character `"` (`0x22`) is explicitly omitted from the escaped set. If the decrypted plaintext contains an unescaped double-quote, the literal `b"..."` closes prematurely, leading straight to Python code injection.

The sandbox redirects standard output to `/dev/null`, but the process's standard output is tied to the raw network socket, and the Landlock rules explicitly permit reading `/flag`. The only feedback the service emits is whether the child process exited cleanly (`[ok]`) or crashed with an exception (`[!]`). This provides a 1-bit oracle: whether a decrypted block contains an unescaped quote character.

## Byte recovery via crash oracle

Under AES-CBC, the plaintext for ciphertext block $C$ is $P = D(C) \oplus \text{IV}$. By fixing $C$ and varying byte $j$ of a candidate IV, exactly one byte value causes $P[j] = \texttt{0x22}$ (a syntax error or unhandled quote that triggers a crash). When that crash occurs, we learn:

$$D(C)[j] = \text{IV}[j] \oplus \texttt{0x22}$$

Sweeping through all 16 byte positions recovers $D(C)$ entirely.

With the raw block decryptions $D(C_1)$ and $D(C_2)$ known, we choose our desired two-block injection payload:

$$P_1 \mathbin{\Vert} P_2 = \texttt{");print(open(\"/flag\").read())##"}$$

We then work backwards through the CBC relation:
1. Set $C_2$ to any arbitrary 16-byte block.
2. Recover $D(C_2)$.
3. Set $C_1 = D(C_2) \oplus P_2$.
4. Recover $D(C_1)$.
5. Set $\text{IV} = D(C_1) \oplus P_1$.

Submitting $\text{IV} \mathbin{\Vert} C_1 \mathbin{\Vert} C_2$ causes the server to decrypt our exact payload, escape none of the quotes, execute the injected Python command, and write `/flag` directly back to the socket:

```python
import sys, os
from pwn import remote, context

context.log_level = 'error'

HOST = sys.argv[1]
PORT = int(sys.argv[2])
TOKEN = sys.argv[3].encode()

def xor(a, b):
    return bytes(x ^ y for x, y in zip(a, b))

CODE = b'");print(open("/flag").read())#'
CODE += b'#' * ((16 - len(CODE) % 16) % 16)
assert len(CODE) == 32
P1, P2 = CODE[:16], CODE[16:]

r = remote(HOST, PORT, timeout=30)
r.recvuntil(b"password: ")
r.sendline(TOKEN)
r.recvuntil(b"New name (iv:ciphertext, in hex): ")

def mkline(iv, ct):
    return iv.hex().encode() + b":" + ct.hex().encode() + b"\n"

def batch(lines):
    r.send(b"".join(lines))
    out = []
    for _ in lines:
        resp = r.recvuntil(b"\n")
        out.append(b"lmao" in resp)
    return out

def find_base(ct):
    for _ in range(40):
        iv = os.urandom(16)
        if not batch([mkline(iv, ct)])[0]:
            return bytearray(iv)
    raise RuntimeError("no clean base found")

def learn_block(ct):
    base = find_base(ct)
    D = bytearray(16)
    for j in range(16):
        found = None
        for start in range(0, 256, 64):
            chunk = list(range(start, min(start + 64, 256)))
            lines = []
            for v in chunk:
                iv = bytearray(base)
                iv[j] = v
                lines.append(mkline(bytes(iv), ct))
            res = batch(lines)
            for v, crashed in zip(chunk, res):
                if crashed:
                    found = v
                    break
            if found is not None:
                break
        assert found is not None, f"byte {j} no crash"
        D[j] = found ^ 0x22
    return bytes(D)

C2 = b'A' * 16
D2 = learn_block(C2)
C1 = xor(D2, P2)
D1 = learn_block(C1)
IV = xor(D1, P1)

r.send(mkline(IV, C1 + C2))
data = r.recvuntil(b"database", timeout=15)
print(data.decode(errors="replace"))
r.close()
```

Solve: `solve/solve.py`

Flag: `K17{yaaaaaaay_i_h0pE_yoU_D1dn7_cra5H_0Ut!!!!!!!!!!!}`
