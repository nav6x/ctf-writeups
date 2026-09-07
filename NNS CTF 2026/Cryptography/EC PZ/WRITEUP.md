# EC PZ (NNS CTF, crypto)

This is an elliptic-curve challenge where the curve itself is hidden. The prime `p` and the curve coefficients `a` and `b` are never printed. All you get are three points `P`, `Q = 2P`, `R = 2Q`, and an encrypted point `C = next_prime(0x133713371337) * F`, where `F = lift_x(bytes_to_long(flag))`. The flag lives in the x-coordinate of `F`, so the plan is to undo that scalar multiplication, and to do that you first have to reconstruct the whole curve from nothing but the points.

Recovering `p` is the nice part. Every point on the curve satisfies the Weierstrass equation `y^2 = x^3 + a*x + b (mod p)`, which you can rearrange to `y^2 - x^3 - a*x - b ≡ 0 (mod p)`. Treat that as a linear relation in the unknowns `a`, `b`, and `1`, with coefficients `x`, `1`, and `y^2 - x^3`. If you stack three points into a 3x3 matrix of those rows, the determinant is a linear combination of the curve equation evaluated at each point, so it is `≡ 0 (mod p)`. Computed over the integers it's some multiple of `p`. Do that for every group of three points you have and take the GCD of all the resulting determinants; the common factor of `p` survives while the random cofactors cancel out. That gave a 257-bit multiple of `p`, whose 256-bit prime factor is `p`.

With `p` known, `a` and `b` come from a single 2x2 linear solve using two of the points, and you can sanity-check the recovered curve by verifying `2P == Q` and `2Q == R` on it.

The rest is standard. Count the group order `n = #E` with Schoof-Elkies-Atkin (SEA), note that the encryption multiplier is `next_prime(0x133713371337)` and that `ord(C) = n/3` with the multiplier coprime to that order, so the multiplication is invertible. Recover `F = k^-1 * C` and read `F.x` back as `bytes_to_long(flag)`.

The lesson worth keeping: the `P`, `Q`, `R` triple isn't there for the doubling relation at all. It's there purely to give you enough independent `y^2 - x^3` rows to pin down the modulus. Any time a curve challenge withholds `p` but hands you three or more points, the determinant-GCD trick is the first thing to reach for.

Solve: `solve/solve.sage`

Flag: `NNS{2_EC_f0r_u_1_gu355}`
