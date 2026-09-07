# hello (COMPFEST 18, crypto)

At first glance this looks like a scary custom RSA built over the polynomial ring `Z_N[x]/(x^10 - 2)`, with `phi = (p^10 - 1)(q^10 - 1)`. The exotic ring had me overthinking it, but the key-generation line gives the whole thing away.

The keygen computes `e = inverse_mod(phi - d, phi)`. That means `e * (phi - d) == 1 (mod phi)`, which rearranges to `e * d == -1 (mod phi)`, so `e * d = k*phi - 1` for a small `d`. That is exactly the setup for Wiener's attack: when the private exponent `d` is small relative to the modulus, the fraction `e/N` has `d` as one of the denominators in its continued-fraction expansion. So the whole ring is a red herring for the key-recovery half of the problem.

Run the continued fraction on `e / N^10`, and one of the convergents hands you `d` and `phi`. From `phi` you get `p^10 + q^10 = N^10 + 1 - phi`, and combined with `p^10 * q^10 = N^10` that's just a quadratic, so you solve for `p^10` and `q^10`, take tenth roots, and factor `N`.

The one gotcha that ate a couple of runs is the decryption itself. `x^10 - 2` is not irreducible mod `p` or mod `q`, so the quotient ring splits into smaller fields and the real unit-group order is much smaller than `phi`. Inverting `e` modulo `phi` gives the wrong exponent and `c^D` comes back as garbage. You have to factor `x^10 - 2` over `GF(p)` and `GF(q)`, multiply the orders of the resulting field unit groups, and invert `e` modulo that instead. Then `m = c^D` in the ring, read the ten coefficients back as the ten message chunks, strip the padding, and rebuild using the sha256-tail rule the challenge prints. Everything is offline from the given file, so there's no server involved.

Flag format is `COMPFEST18{...}` and it falls out of the rebuild when you run the solver.

Solve: `solve/solve.sage` (and `solve/hello_solve.sage`)

Flag: `COMPFEST18{c0ngr4tzzz_h3ngk3rrrr_g3n3r4l1Zed_w13n3R_4ttacK_f91f71b7c1b857d2}`
