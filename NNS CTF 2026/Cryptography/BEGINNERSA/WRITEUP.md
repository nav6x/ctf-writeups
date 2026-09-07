# BeginneRSA (NNS CTF, crypto)

You get two RSA public keys, and the whole thing collapses the moment you notice how the primes were chosen.

The one assumption RSA rests on is that factoring the modulus `N` back into its two primes is hard. Here the two moduli are `N1 = p*q` and `N2 = q*getPrime(512)`, and the same prime `q` was reused to build both of them. That reuse is the entire vulnerability. When two moduli share a factor, you don't have to factor either one the hard way, because the shared prime is just their greatest common divisor. Euclid's algorithm computes `gcd(N1, N2)` on two thousand-bit numbers in a fraction of a second, so `q` drops straight out, and then `p = N1 // q`.

From there it's ordinary RSA. With `p` and `q` in hand you compute `phi = (p-1)*(q-1)`, invert the public exponent to get the private key `d = e^-1 mod phi` (with `e = 0x10001`), and decrypt `m = c1^d mod N1`. Turn `m` back into bytes and the flag is sitting there.

The `c2` / `notflag` values in the output are a distraction and have nothing to do with the flag, so don't waste time on them.

The one thing that actually cost me a run: read the big integers directly from the file instead of retyping them. They're hundreds of digits long, and a single mistyped digit makes `gcd(N1, N2)` come back as `1`, which makes the whole approach look broken when it isn't.

Solve: `solve/solve.py`

Flag: `NSS{n3v3r_3v3r_r3u53_4_pr1m3!}`
