# Crypto Party 2 (NNS CTF, crypto)

The flag is AES-ECB encrypted, and the AES key is literally the ECDSA private key (`key = long_to_bytes(secret_key, 32)`). So recovering the signing key recovers the flag, and the way in is the nonce.

Every ECDSA signature uses a per-signature random nonce `k`, and the security of the scheme depends entirely on `k` being unpredictable and fully secret. If you know even part of each nonce across several signatures, you can recover the private key with a lattice, and that whole family of attacks is the Extended Hidden Number Problem (EHNP).

Look at how the nonce is generated here: `k = bytes_to_long(str(uuid.uuid4())[:32].encode())`. A UUID4 string looks like `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`, and taking the first 32 characters gives you a 256-bit integer whose bytes are almost entirely known or constrained. The dashes are fixed at positions 8, 13, 18, 23 (byte `0x2d`), position 14 is always `'4'`, and every remaining byte is an ASCII hex digit, so it's restricted to `0x30-0x39` or `0x61-0x66`. That leaves only about 106 genuinely random bits, spread across known positions. That is exactly the shape EHNP eats.

The curve is P-256 (NIST256p). Collect all six signatures the service will give you (`MAX_INVITES = 6`) for chosen message names `"0"` through `"5"`, with `h_i = int(sha256(name))`. Model each nonce as `k_i = A + sum_p 256^(31-p) * delta_p`, where `A` is the fixed skeleton of known bytes (the same constant in every signature) and each `delta_p` is a small correction, `|delta| <= 27`, centered at 75 to cover the hex-digit range. Then use the ECDSA relation `s*k = h + r*d (mod n)` and eliminate the unknown private key `d` by subtracting a reference signature, which turns six signatures into five congruences in 162 small unknowns.

Build a lattice from those congruences. The trick that makes it actually work is to weight the congruence columns by a large factor `K = 2^400`, which forces the reduction to satisfy them exactly (zero residue) rather than just approximately. Run LLL, read off the row whose homogeneous coordinate is `±27`, reconstruct `k0`, and back out `d`. Then AES-ECB decrypt the ciphertext with `d` as the key.

Two things that bit me. Plain LLL with `K = 1` sits right at the Gaussian heuristic and returns garbage; it's the large-`K` weighting that isolates the true short vector, and once that's in place LLL alone is enough (BKZ-30 verified 5 out of 5 on local instances). Also, pycryptodome isn't installed in Sage's Python here, so do the final AES decrypt in system `python3`.

Solve: `solve/collect.py`, `solve/fast.sage`

Flag: `NNS{bu7_uu1ds_4r3_r4nd0m!!_918486dc6f}`
