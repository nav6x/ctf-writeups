# blowfish (K17 CTF, crypto)

The challenge runs a remote service using Blowfish-CBC on 8-byte blocks. The goal is to submit an authenticated plaintext whose JSON payload contains `"admin": true`.

## The MAC structure

The server signs any byte string using a per-block SHA-256 MAC:

$$\text{sign}(B_1 \mathbin{\Vert} B_2 \mathbin{\Vert} \dots \mathbin{\Vert} B_n) = \text{SHA256}(K \mathbin{\Vert} B_1) \mathbin{\Vert} \dots \mathbin{\Vert} \text{SHA256}(K \mathbin{\Vert} B_n)$$

Because the signature is simply the concatenation of independent signatures over individual 8-byte blocks, any message composed entirely of blocks whose individual signatures we have seen can be forged directly.

The catch is chicken-and-egg: every query to the encryption or decryption oracle requires a valid signature on the input. However, the initial connection handshake hands us a signed `iv_fish` string that already contains `{"admin"`.

## Forging signatures with CBC

Consider encrypting a two-block message $A \mathbin{\Vert} B$ under CBC mode:
- The first ciphertext block is $C_1 = E(A \oplus \text{IV})$.
- If we pass $A \mathbin{\Vert} B$, the server computes $C = E(A \oplus B)$ and returns its signature.

Next, decrypting $c \mathbin{\Vert} C \mathbin{\Vert} \text{dummy}$:
- The plaintext produced for the second block is $D(C) \oplus c = (A \oplus B) \oplus c$.
- Because the server returns the signature of that decrypted block, we obtain a valid signature for the XOR sum $A \oplus B \oplus c$ of any three blocks whose signatures we already hold.

By chaining this three-block gadget, any odd-length XOR combination of known signed blocks can be signed. We use linear algebra over $\text{GF}(2)$ on the 64-bit blocks to express the missing block `:true  }` as an odd linear combination of known blocks, chain the queries, and assemble the full signed payload:

```python
from pwn import remote, context
import json

context.log_level = 'error'

HOST, PORT = 'chal.secso.cc', 2001

def b2i(b):
    return int.from_bytes(b, 'big')

def i2b(i):
    return i.to_bytes(8, 'big')

class Solver:
    def __init__(self):
        self.r = remote(HOST, PORT, timeout=20)
        self.pool = {}
        self._handshake()

    def _ingest(self, fishhex, sighex):
        raw = bytes.fromhex(fishhex)
        sigs = [sighex[i:i+64] for i in range(0, len(sighex), 64)]
        for idx, off in enumerate(range(0, len(raw), 8)):
            blk = raw[off:off+8]
            if len(blk) == 8:
                self.pool[blk] = sigs[idx]

    def _handshake(self):
        r = self.r
        r.recvuntil(b'Fish: ')
        fish = r.recvline().strip().decode()
        r.recvuntil(b'Signature: ')
        sig = r.recvline().strip().decode()
        self._ingest(fish, sig)

    def sign_of(self, msg):
        out = ''
        for i in range(0, len(msg), 8):
            out += self.pool[msg[i:i+8]]
        return out

    def _menu(self, choice, data, prompt_in):
        r = self.r
        r.recvuntil(b'? ')
        r.sendline(str(choice).encode())
        r.recvuntil(prompt_in)
        r.sendline(data.hex().encode())
        r.recvuntil(b'Sign the fish: ')
        r.sendline(self.sign_of(data).encode())
        line = r.recvline()
        return line

    def encrypt(self, plaintext):
        line = self._menu(1, plaintext, b'Enter fish: ')
        assert b'swimmingly' in line, line
        fish = line.split(b': ')[1].strip().decode()
        self.r.recvuntil(b'Signature: ')
        sig = self.r.recvline().strip().decode()
        self._ingest(fish, sig)
        return bytes.fromhex(fish)

    def decrypt(self, ciphertext):
        line = self._menu(2, ciphertext, b'Enter up-blown/unup-unblown fish: ')
        assert b'point:' in line, line
        fish = line.split(b'point: ')[1].strip().decode()
        self.r.recvuntil(b'Signature: ')
        sig = self.r.recvline().strip().decode()
        self._ingest(fish, sig)
        return bytes.fromhex(fish)

    def forge3(self, a, b, c):
        out = self.encrypt(a + b)
        C = out[8:16]
        dummy = next(iter(self.pool))
        out2 = self.decrypt(c + C + dummy)
        target = out2[8:16]
        assert b2i(target) == (b2i(a) ^ b2i(b) ^ b2i(c)), (target.hex(),)
        return target

    def build_basis(self):
        self.blocks = list(self.pool.keys())
        basis = {}
        self.odd_null = None
        for idx, blk in enumerate(self.blocks):
            v = b2i(blk)
            combo = {idx}
            bit = 63
            while v:
                hb = v.bit_length() - 1
                if hb in basis:
                    bv, bc = basis[hb]
                    v ^= bv
                    combo ^= bc
                else:
                    basis[hb] = (v, combo)
                    combo = None
                    break
            if combo is not None and combo:
                if len(combo) % 2 == 1 and self.odd_null is None:
                    self.odd_null = combo
        self.basis = basis

    def represent(self, target_int):
        v = target_int
        combo = set()
        while v:
            hb = v.bit_length() - 1
            if hb not in self.basis:
                return None
            bv, bc = self.basis[hb]
            v ^= bv
            combo ^= bc
        return combo

    def warmup(self, n):
        ks = list(self.pool.keys())
        for i in range(n):
            a = ks[i % len(ks)]
            b = ks[(i * 7 + 3) % len(ks)]
            self.encrypt(a + b)

    def sign_block(self, T):
        if T in self.pool:
            return
        self.build_basis()
        combo = self.represent(b2i(T))
        if combo is None:
            self.warmup(30)
            self.build_basis()
            combo = self.represent(b2i(T))
        assert combo is not None, "target not in span of pool"
        if len(combo) % 2 == 0:
            assert self.odd_null is not None, "no odd null relation"
            combo ^= self.odd_null
        idxs = sorted(combo)
        assert len(idxs) % 2 == 1
        blks = [self.blocks[i] for i in idxs]
        cur = blks[0]
        if len(blks) > 1:
            cur = self.forge3(blks[0], blks[1], blks[2])
            j = 3
            while j < len(blks):
                cur = self.forge3(cur, blks[j], blks[j+1])
                j += 2
        assert cur == T, (cur.hex(), T.hex())

    def win(self):
        iv = next(iter(self.pool))
        admin = b'{"admin"'
        assert admin in self.pool
        T = b':true  }'
        self.sign_block(T)
        P = iv + admin + T
        assert json.loads(P[8:]).get("admin") is True
        r = self.r
        r.recvuntil(b'? ')
        r.sendline(b'1')
        r.recvuntil(b'Enter fish: ')
        r.sendline(P.hex().encode())
        r.recvuntil(b'Sign the fish: ')
        r.sendline(self.sign_of(P).encode())
        print(r.recvline().decode().strip())

if __name__ == '__main__':
    s = Solver()
    s.win()
    s.r.close()
```

Solve: `solve/solve.py`

Flag: `K17{great_work_infiltrating_as_the_head_fish_perhaps_one_could_call_you_james_pond}`
