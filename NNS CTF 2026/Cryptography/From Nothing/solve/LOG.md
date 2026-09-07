# Session log — NNS CTF "From Nothing"

Chronological record of how the challenge was attacked, including the wrong turns.
Times are local (2026-09-05). Working environment: Windows 11 host, SageMath inside
`wsl -d kali-linux`, artefacts under WSL `/tmp/fn_*`.

---

## Phase 0 — prior session (wrong framing)

An earlier session read the challenge under the assumption that it was a very
high-value, near-unsolved problem, and went looking for the group order by **direct
point counting**: `H.frobenius_polynomial()` / naive Frobenius on the genus-5 curve.

* Result: intractable. Too slow even at **26-bit** primes, let alone the real 512-bit `p`.
* This consumed most of that session and produced nothing usable.

## Phase 1 — re-read with correct difficulty signal

The scoreboard shows **161 pts / 31 solves**, not 500/1. Thirty-one teams did not
point-count a genus-5 Jacobian over a 512-bit field. That reframing forced the question:
*what closed form gives `#J` for free?*

Challenge re-read (`crypto_from-nothing/chall.sage`):

```
n = 11 ; p 512-bit, p % 11 == 1
H : v^2 + v = u^11            genus 5
D = k * J(H.lift_x(x0))       x0 chosen with (1+4*x0^11) square
e = int(D[1][0])              SECRET
ct = e * J(H.lift_x(flag_int))
GIVEN: p, D_u = D[0].list(), ct[0], ct[1].     D_v is withheld.
```

Two observations that set the whole solution:

1. **"the wise seek not what is present, but what is absent"** — the withheld object is
   `D_v`, and `e` is literally its constant term. So `e` is meant to be *reconstructed*,
   not discrete-logged. A reduced Mumford divisor obeys the curve equation mod `u_D`:
   `(2v+1)^2 ≡ 1 + 4x^11 (mod u_D)`. Factor `u_D`, square-root per factor, CRT the sign
   choices. Small candidate set.
2. `v^2+v=u^11` has the automorphism `u -> ζ_11 u`, so `End(J) ⊇ Z[ζ_22]`, `[Q(ζ_22):Q] =
   10 = 2·genus`. **CM abelian fivefold** — `#J` has a closed form via the Weil number.

## Phase 2 — validating step 1 (and step 3) on small primes

Wrote `/tmp/fn_validate.sage` (now `validate_small.sage`): generate complete challenge
instances over small `p ≡ 1 mod 11` where `H.frobenius_polynomial()` gives ground truth,
then check `e_true ∈ candidates`, `#J·ct == 0`, and full flag recovery.

* First attempt died on a `pari` import / allocation issue → fixed with
  `from sage.all import pari; pari.allocatemem(1<<28)`.
* First clean run: `e_true` **always** in candidates; `#J` **always** annihilates `ct`.
  A few primes reported `flag_recovered=False`.
* Diagnosis of the failures: `gcd(e, #J) != 1`, i.e. `e` not invertible mod the full
  order. Patch: invert modulo the **`e`-coprime part** of `N` (repeatedly divide out
  `gcd`, no factoring needed).
* Two primes still failed after the patch. Debugged `p = 89` directly: the real cause is
  `gcd(e, ord(P)) = 11` — in a tiny group `e` genuinely kills the point. This is a
  degenerate small-group artefact that cannot occur for a `~p^5` order with a random
  512-bit `e`. `p = 67, 199, 353, 397` recover cleanly.
* **Verdict: steps 1 and 3 fully validated against ground truth.**

## Phase 3 — first CM approach (superseded)

Built a candidate `#J` generator in `Q(ζ_11)`: factor `(p)`, pick one prime from each
conjugate pair (`2^5` CM types), take the generator, then **reduce by the unit lattice**
(least-squares in the log-embedding space) to force `|σ(π)| = √p`, times `ζ_11^k`.
~72 candidates. Validated on tiny primes: the true `#J` was **always** among them.

Then benchmarked one genus-5 scalar multiplication at the real 512-bit `p`: ≈ 24 s.
72 candidates ⇒ ~30 min. Workable but clumsy. This is what is preserved in `solve.sage`.

## Phase 4 — the clean CM approach (this is the one that solved it)

Replaced the unit-lattice reduction with **Stickelberger's theorem**. For the
superelliptic curve `w^2 = 4u^11 + 1`, the Frobenius ideal is a Jacobi-sum ideal of type
`(2, 11, 13)` in `K = Q(ζ_22)` (`2 + 11 + 9 ≡ 0 mod 22`, `9 ≡ -13`):

```
(π) = ∏_{c ∈ (Z/22)^*} σ_c(P)^{e_c},
e_c = ⟨-2c⁻¹/22⟩ + ⟨-11c⁻¹/22⟩ - ⟨-13c⁻¹/22⟩
```

`h(Q(ζ_22)) = 1` gives a generator `g0`; two generators of the same ideal with all
`|σ| = √p` differ only by a **root of unity**, so no lattice reduction is needed at all.
That leaves exactly **22** candidates `ζ_22^k · g0`, and `#J = Norm_{K/Q}(1-π)`.

Script `/tmp/fn_final.sage` (now `solve_final.sage`):

1. build the 22 candidate orders,
2. test each with `N * ct == 0` in `J`,
3. reconstruct the `e` candidates from `D_u`,
4. `(e^{-1} mod N) * ct`, read the degree-1 `u`-polynomial, decode.

Output (`solve_final.out`):

```
candidate orders: 22
  idx 0..14 not annihilator
FOUND N (idx 15): 370688966215642044295025782304325479458041981798963120457389868900996092648083446777...
testing 8 e-candidates
  decode: b'NNS{4nd_th3_g1ft3d_c4n_m4k3_s0m3th1ng_fr0m_n0th1ng}'
FLAG: b'NNS{4nd_th3_g1ft3d_c4n_m4k3_s0m3th1ng_fr0m_n0th1ng}'
exit=0
```

16 scalar multiplications × ~24 s ≈ 7 minutes wall clock.

## Phase 5 — packaging

Copied the winning artefacts out of WSL `/tmp` into the challenge folder, wrote
`HANDOFF.md` (full method + validation record + dead ends), this log, and
`CONTINUE_PROMPT.md`. Re-ran `confirm.sage` against the published `N` to record the
recovered `e` and re-derive the flag independently of the original run.

## Timeline of files

| time | file | note |
|---|---|---|
| 02:15 | `crypto_from-nothing.tar.gz` | challenge downloaded |
| 02:27–02:42 | `/tmp/fn_small.sage`, `fn_formula.sage`, `fn_solve.sage`, `fn_solve2.sage` | exploratory |
| 02:28 | `/tmp/fn_bigN.sage` | first CM order attempts |
| 03:03–03:05 | `/tmp/fn_selftest.sage`, `fn_time.sage`, `fn_probe.sage`, `fn_final.sage` | timing + the winning solver |
| **03:11** | **`/tmp/fn_final.out`** | **FLAG** |
| 03:43 | `/tmp/fn_validate.sage` | post-hoc ground-truth validation |
| 03:55 | `solve.sage` | superseded 72-candidate writeup version |
| 05:37+ | `solve_final.sage`, `validate_small.sage`, `solve_final.out`, `HANDOFF.md`, `LOG.md`, `confirm.sage` | packaged |

## Cost of the wrong turns

* Point counting on the real curve: the single largest time sink, across two sessions.
  The scoreboard rating was the cheapest available signal that it was wrong, and it was
  not consulted early enough.
* Unit-lattice CM reduction: correct but 3× more candidates than necessary. Stickelberger
  makes the unit problem disappear entirely.

## Phase 6 — independent re-confirmation

`confirm.sage` re-derived the flag from `output.txt` in a separate process with the
winning `N` hardcoded, and printed the secret scalar:

```
N bits: 2557   p^5 bits: 2557
N*ct == 0 : True
u_D factor degrees: [1, 2, 2]
e candidates: 8
CONFIRMED FLAG: NNS{4nd_th3_g1ft3d_c4n_m4k3_s0m3th1ng_fr0m_n0th1ng}
e = 3647271236260210458855469835989950549486584880970316012815181976598448138325192006449421023093068919671263208738005031797683688088589700074422591642985289
```

Everything checks: `#J` is 2557 bits = `p^5` bits exactly, and `u_D`'s factor degrees
`[1,2,2]` (three factors) explain the 8 `e`-candidates as `2^3` sign choices. Session
closed — all artefacts are on disk in this folder; nothing further is needed from the
chat transcript.
