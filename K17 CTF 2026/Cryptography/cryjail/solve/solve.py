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
