#!/usr/bin/env python3

from Crypto.Cipher import AES
from hashlib import sha256
import multiprocessing as mp, time

A, C, M = 16843009, 826366247, 2**32
CT = bytes.fromhex(
    "85c43735b8442a69843bdc2ca0fb2d41eb548057c43b912704abdf2e27a8d8bc"
    "97017ec30b5d100498f12183c9e2ebed"
)

a, c = 1, 0
for _ in range(1337):
    a = (A * a) % M
    c = (A * c + C) % M

def work(rng):
    lo, hi = rng
    for s in range(lo, hi):
        seed = (a * s + c) % M
        key = sha256(str(seed).encode()).digest()
        if AES.new(key, AES.MODE_ECB).decrypt(CT)[:4] == b"NNS{":
            return (s, AES.new(key, AES.MODE_ECB).decrypt(CT))
    return None

if __name__ == "__main__":
    now = int(time.time())
    lo, hi = now - 120 * 86400, now + 2 * 86400
    nproc = 6
    step = (hi - lo) // nproc + 1
    chunks = [(lo + i * step, min(lo + (i + 1) * step, hi)) for i in range(nproc)]
    t = time.time()
    with mp.Pool(nproc) as p:
        for r in p.imap_unordered(work, chunks):
            if r:
                p.terminate()
                print("timestamp:", r[0])
                print("flag:", r[1])
                break
        else:
            print("not found in window; widen it")
    print("elapsed %.1fs" % (time.time() - t))
