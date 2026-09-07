#!/usr/bin/env python3

from math import gcd
from pathlib import Path

def long_to_bytes(n):
    return int(n).to_bytes((int(n).bit_length() + 7) // 8, "big")

vals = {}
for line in (Path(__file__).parent / "crypto_beginnersa" / "output.txt").read_text().splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        vals[k.strip()] = int(v)

N1, N2, c1 = vals["N1"], vals["N2"], vals["c1"]
q = gcd(N1, N2)
assert q > 1, "no shared prime (check you read output.txt, not a retyped number)"
p = N1 // q
e = 0x10001
d = pow(e, -1, (p - 1) * (q - 1))
print(long_to_bytes(pow(c1, d, N1)))
