# Nostalgia (NNS CTF, crypto)

The encryption is AES-ECB, and the AES key is derived from a random seed, so the whole challenge is really about how weak that seed is.

The code does `seed = time.time()`, runs the seed through 1337 rounds of a linear congruential generator, then sets `key = sha256(str(seed))` and encrypts the flag with AES-ECB. A comment claims the seed has nanosecond precision, which would make brute force hopeless. That comment is a lie. The very first thing the LCG does is `int(seed)`, which truncates the float down to a whole number of seconds. So no matter what the fractional part was, the effective seed is just a Unix timestamp, which is only about 31 bits of entropy and completely bruteforceable.

The LCG itself is `lcg(s) = (16843009*s + 826366247) mod 2^32`. An LCG is an affine map, `s -> a*s + c`, and composing affine maps just gives another affine map. So instead of iterating 1337 times per candidate, I collapse all 1337 rounds into a single `a'*s + c'` and apply it once, which makes each guess almost free.

From there it's a straight brute force over Unix timestamps, spread across 6 cores. For each candidate `seed`, derive `key = sha256(str(seed))`, AES-ECB decrypt the ciphertext, and check for the `NNS{` prefix. It lands at timestamp `1788275074`.

Solve: `solve/solve.py`

Flag: `NNS{th3_b3st_t1m3_t0_m4k3_m3m0r13s_15_n0w}`
