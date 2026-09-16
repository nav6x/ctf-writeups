import math
from pathlib import Path

p = Path(__file__).resolve().parent.parent / "handout" / "out.txt"
if not p.exists():
    p = Path("out.txt")

with open(p) as f:
    text = f.read()

exec(text)

e = 257

for kp in range(1, e):
    for kq in range(1, e):
        S = e * leak - 2 + kp + kq
        disc = S * S - 4 * kp * kq * N
        if disc >= 0:
            sq = math.isqrt(disc)
            if sq * sq == disc:
                P = (S + sq) // (2 * kp)
                if P > 0 and N % P == 0:
                    Q = N // P
                    phi = (P - 1) * (Q - 1)
                    d = pow(e, -1, phi)
                    m = pow(c, d, N)
                    print(m.to_bytes((m.bit_length() + 7) // 8, "big").decode())
                    exit(0)
