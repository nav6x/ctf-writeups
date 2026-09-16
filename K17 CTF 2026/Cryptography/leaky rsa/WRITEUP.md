# leaky rsa (K17 CTF, crypto)

We are handed an RSA challenge with $e = 257$, two 1024-bit primes $P$ and $Q$, and a leak of $d_{sum} = d_p + d_q$, where $d_p \equiv d \pmod{P-1}$ and $d_q \equiv d \pmod{Q-1}$.

## Recovering the primes

The definitions of CRT exponents give:

$$e \cdot d_p = 1 + k_p (P - 1)$$
$$e \cdot d_q = 1 + k_q (Q - 1)$$

Since $d_p < P - 1$ and $d_q < Q - 1$, the multipliers $k_p$ and $k_q$ are strictly bounded by $1 \le k_p, k_q < e = 257$. That leaves a search space of only $256 \times 256 \approx 65{,}536$ candidate pairs.

Summing the two relations:

$$e(d_p + d_q) - 2 = k_p(P - 1) + k_q(Q - 1)$$
$$k_p P + k_q Q = e \cdot \text{leak} - 2 + k_p + k_q \equiv S$$

Multiplying by $P$ and substituting $P \cdot Q = N$:

$$k_p P^2 - S \cdot P + k_q N = 0$$

For the correct choice of $(k_p, k_q)$, the quadratic discriminant $\Delta = S^2 - 4 k_p k_q N$ must be a perfect square over the integers, and solving the quadratic yields the prime factor $P$:

```python
import math

with open("out.txt") as f:
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
```

The search hits at $k_p = 230, k_q = 135$ and spits out the flag in under a tenth of a second.

Solve: `solve/solve.py`

Flag: `K17{th3_t1tan1c_sh0uldv3_us3d_duct_t4p3}`
