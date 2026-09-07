# Light-Weight Encryption (NNS CTF, crypto)

The flag itself names the paper this is based on: Compact-LWE, ePrint 2017/742. It's a lattice scheme, and the break is a four-stage lattice attack that peels it apart one secret at a time.

The parameters are `q = 2^768`, `n = 16`, `m = 112`, `w = 130`, `b = 16`. The public relation is `B = A*s + k*e (mod q)`, where `A` has small entries (0 to 15), `e` is a small error, `s` is a full-size secret, and `k = p/sk mod q` for a 520-bit prime `p` and a 128-bit prime `sk`. A ciphertext picks `w = 130` random rows `I` and sends `u = sum A[i]` and `v = pt - sum B[i]`, so decryption is really `pt = v + u*s + k*E (mod q)` with `E = sum_{i in I} e[i]` (around 2^39).

The instinct is to solve for that error sum `E`, and that's the trap. It turns into a degenerate 2D closest-vector problem near `q` that never gives the right answer. The way through is to never touch `E` and instead recover the private key pieces directly.

Stage 1 recovers the hidden multiplier `k`. Take the integer left-kernel of `A` (LLL-reduced, small entries), which kills the `s` term: for a kernel vector `c`, `c*B ≡ k*(c*e) (mod q)`, and `c*e` is small (around 2^35). Setting `a_j = c_j*B mod q`, you want `y = k^-1` such that every `a_j*y mod q` is small. Build the lattice `M[0] = [1, F*a_1..F*a_L]`, `M[j+1] = F*q*e_j` with `F = 2^728`; the true row has `|delta| ≈ 2^34` and is unique (everything else is around 2^760). Then `k = inverse_mod(y, q)`.

Stage 2 recovers `s`, but only up to an ambiguity that turns out not to matter. Compute `Bp = k^-1*B = A*s' + e (mod q)` with `s' = k^-1*s`. Babai nearest-plane on the lattice `Lambda = <cols of A> + q*Z^m` with target `Bp - 2^31` gives some short `e`; solve `A*s' = P (mod q)` on a mod-2-invertible 16-row minor, then `s = k*s'`. The recovered `s` isn't unique, but the ambiguity is always a multiple of `p`, which cancels in the final decryption.

Stage 3 pulls `sk` and `p` out of `k`. Reduce the 2D lattice `[[2^392, k], [0, q]]` with LLL; the correct row has coordinates `(sk*2^392, p)` in absolute value, and it usually comes out negated, so take `abs()`: `sk = |r0|/2^392` (128-bit prime), `p = |r1|` (520-bit prime).

Stage 4 decrypts. Compute `w = (v + u*s) mod q`, then `X = (sk*w) mod q` (subtract `q` if it's near 2^768), and finally `pt = (X mod p) // sk`. Decode that and you have the flag.

The general lesson for Compact-LWE and any LWE-with-hidden-multiplier variant: don't solve for the error sum, recover `sk` and `p` and use the intended `((sk*w mod q) mod p)/sk` decryption. Both the `s` ambiguity and the `k*sk ≡ ±p` sign wash out modulo `p`. (Sage's Python doesn't have pycryptodome, so inline `long_to_bytes`.)

Solve: `solve/solve.sage` (with `solve/sim.sage` validating the full chain on a known-plaintext instance)

Flag: `NNS{lwe,compact,broken:https://eprint.iacr.org/2017/742.pdf}`
