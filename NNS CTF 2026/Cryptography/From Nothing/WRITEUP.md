# From Nothing (NNS CTF, crypto)

This was the hard one. The scheme is ElGamal-style encryption on the Jacobian of a hyperelliptic curve, and the flag comes out of a scalar multiplication you can only invert if you know the size of the group.

The curve is `v^2 + v = u^11` over a 512-bit `GF(p)` with `p ≡ 1 mod 11`. That's a genus-5 curve, and its Jacobian is where the group operations happen. Encryption is `ct = e * P` in the Jacobian for a secret scalar `e`, and to recover the plaintext point `P` you need `P = e^-1 * ct`, which requires computing `e^-1` modulo the group order `#J`. So the entire challenge reduces to: find `#J`, the number of points on the Jacobian.

The obvious approach, point counting, is a dead end at this size. p-adic methods like Kedlaya's algorithm (and Sage's `CyclicCover`) are intractable for a 512-bit field, and PARI's p-adic `gamma()` overflows. You cannot brute or compute your way to `#J` directly.

What makes it tractable is the extra structure. This curve is superelliptic with a large automorphism group, so its Jacobian has complex multiplication by `Z[zeta_11]`, and that field has class number 1. That means the Frobenius endomorphism is a Jacobi sum living in `Z[zeta_11]`, and you can write `#J` in closed form instead of counting anything. The Jacobi sum's ideal factorization comes from Stickelberger's theorem for the superelliptic type `(s, t, s+t) = (2, 11, 13)` over `m = 22`. I locked the prime-indexing convention against brute-forced small primes: `val(sigma_c(P)) = e(-c^-1)` with `e(x) = frac(2x/22) + frac(11x/22) - frac(13x/22)`. The reduced generator is already balanced to norm `sqrt(p)`, which leaves only 22 root-of-unity phases, so you end up with 22 candidate group orders rather than one exact answer.

There's a second recovery you need: the scalar `e`. The output withholds the `D_v` half of a divisor, which looks secret but isn't. You can rebuild it from the given `D_u` using `(2v+1)^2 ≡ 1 + 4u^11 (mod u_D)`, which gives 8 sign-branch candidates for the constant term `e`.

To pin down the correct combination, use the fact that the true group order annihilates the ciphertext: `N * ct = 0` in the Jacobian. Test each of the 22 candidate orders against that and it selects the right one (it was candidate index 15). Then `P = e^-1 * ct` for the correct `e`-branch gives a degree-1 divisor whose x-coordinate decodes straight to the flag.

The takeaway I'd give anyone facing a Jacobian with a big automorphism group (superelliptic or Artin-Schreier curves): reach for Jacobi sums and Stickelberger before you even think about point counting, and never assume a withheld Mumford `v`-polynomial is actually a secret.

Solve: `solve/solve_twostage.sage` (plus `confirm.sage`, `validate_small.sage`, and `HANDOFF.md` / `LOG.md` notes)

Flag: `NNS{4nd_th3_g1ft3d_c4n_m4k3_s0m3th1ng_fr0m_n0th1ng}`
