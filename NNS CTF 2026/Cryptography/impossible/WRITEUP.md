# impossible (NNS CTF, crypto)

This is a Groth16 zero-knowledge challenge on BLS12-381 (bellman 0.1.0). The circuit forces `amount == balance == 100`, but the verifier demands a public input of `amount = CLAIM = 1_000_000_000`. Those two can't both be true, so there is no honest proof. The whole point is that the trusted setup was compromised.

A little background: Groth16 needs a one-time trusted setup that produces a proving/verifying key from a secret value usually called `tau` (the "toxic waste"). Everyone's security depends on `tau` being destroyed after setup, because anyone who still has it can forge a proof for any statement, true or not. So the challenge is really asking: can you get `tau`?

You can, because the shipped `secret` file is just ROT13. Decoding it turns `PRERZBAL_VQ` into `CEREMONY_ID` and `GNH` into `TAU`, handing you the ceremony id `3c311d9dfb7735e42643f394dc2c10af` and `tau` as a decimal field element. That's the toxic waste, in the clear.

With `tau` you rederive the trapdoor using the challenge's own `derive(tau)` (which gives `alpha, beta, gamma, delta, g1s, g2s`) and `mint_ic_scalars(tau, ...)` (which gives `ic0, ic1`). The one non-obvious detail, and it cost a probe binary to confirm, is that the verifying key is built on scaled generators: every G1 point is `g1^(g1s*scalar)` and every G2 point is `g2^(g2s*scalar)`, not the raw generators.

Now forge. The verifier checks `e(A,B) = e(alpha_g1, beta_g2) * e(acc, gamma_g2) * e(C, delta_g2)` with `acc = ic[0] + CLAIM*ic[1]`. Pick `A = g1^a` and `B = g2^b` on the standard generators (I used `a=2, b=3`), then solve the pairing equation for the one remaining unknown `C`:
`c = (a*b - g1s*g2s*(alpha*beta + ic_scalar*gamma)) * (g2s*delta)^-1`, where `ic_scalar = ic0 + CLAIM*ic1`, and `C = g1^c`. All of `A`, `B`, `C` must be non-infinity because `Proof::read` rejects the identity. Verify the forged proof locally against the real `vk.bin` before sending, then submit the line `ceremony_id:hex(proof)` where the proof bytes are the compressed `A || B || C` (48 + 96 + 48).

Two gotchas that wasted time. The README and `solve.rs` connect with plain TCP on port 31337, but the live service is actually SSL on port 1337, so generate the proof offline in Rust and submit it over `openssl s_client -connect host:1337`. And in pairing 0.14.2, `Fr::from_str` needs `use pairing::PrimeField` in scope or it won't compile.

Solve: `handout/src/bin/solve.rs` (the solver lives inside the cargo project)

Flag: `NNS{1mp05s1Bl3_pr00F5_FR0M_C3r3m0Ny_45H3s}`
