import numpy as np, gmpy2, time
from Crypto.Util.number import long_to_bytes, inverse

e = 0x10001
d = {}
exec(open("crypto_nrt/output.txt").read(), d)
N, ct = d["N"], d["ct"]

t = time.time()
LIM = 1 << 24
s = np.ones(LIM, dtype=bool)
s[:2] = False
for i in range(2, int(LIM ** 0.5) + 1):
    if s[i]:
        s[i * i::i] = False
primes = np.nonzero(s)[0]
print("sieve: %.1fs, %d primes" % (time.time() - t, len(primes)))

Nz = gmpy2.mpz(N)
small = [int(p) for p in primes.tolist() if Nz % int(p) == 0]
print("trial-div: %.1fs, small primes=%d" % (time.time() - t, len(small)))

acc, mod = 0, 1
for p in small:
    dp = inverse(e, p - 1)
    mp = pow(ct % p, dp, p)
    g = inverse(mod % p, p)
    acc = (acc + mod * ((mp - acc) * g % p)) % (mod * p)
    mod *= p

print("smooth modulus bits:", mod.bit_length())
print("FLAG:", long_to_bytes(acc % mod))
