# NRT (NNS CTF, crypto)

The hint in the description is that `getPrime` runs in cubic time, so the author generates the modulus a cheaper way: multiply a pile of small 24-bit primes together until `N` grows past 256 bits, then multiply in a few large 4096-bit primes on top "for the security". The idea is that you get a fast build from the small primes and a hard-to-factor modulus from the big ones.

The catch is that the flag is smaller than 256 bits, and the product of just the small primes is already 259 bits. So the message is smaller than the fully smooth (all-small-primes) part of `N`, and the big primes never actually come into play. Everything about the "security half" of the modulus is decoration.

Here's why that breaks it. A 24-bit prime is trivially factorable by trial division, so I sieve primes up to 2^24 and divide them out of `N`. That gives 11 small primes whose product `S` is 259 bits. The generator also asserts `(p-1) % e != 0` for every small prime, which is exactly the condition that `gcd(e, p-1) = 1`, meaning `e` is invertible modulo each `p-1`. So I can run RSA decryption independently on each small prime: `m mod p = (ct mod p)^(e^-1 mod (p-1)) mod p`.

Now I have `m` modulo each of the 11 primes, and the Chinese Remainder Theorem stitches those residues into `m mod S`. Because `m < 2^256 < S`, reducing modulo `S` doesn't lose anything, so `m mod S` is just `m`. Decode it and you have the flag. The full run (sieve, trial division, CRT) takes about 0.7 seconds.

Solve: `solve/solve.py`

Flag: `NNS{n0_n33d_f0r_4ll_pr1m35}`
