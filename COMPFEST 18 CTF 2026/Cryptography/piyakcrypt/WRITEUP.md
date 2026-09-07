# piyakcrypt (COMPFEST 18, crypto)

piyakcrypt looks like a scary ECDSA challenge, but it's really three leaks stacked on top of each other, and the crypto at the end is textbook. Calling it an ECDSA problem is a bit of a misdirection, the actual puzzle is noticing that a "protection" function undoes itself and lining up the Mersenne Twister state.

The data panel runs everything through a `panel_value` transform first, which looks like protection but is just XOR-with-a-salt, a rotate, and an additive bump, fully invertible, so you peel it right off. Under it are 702 raw MT19937 outputs, and MT19937 only needs 624 outputs to clone the entire state. So the RNG is ours before we ever touch a signature. The neat structural coincidence is that 622 skipped words plus two 20-bit tags eat exactly 624 words, which is what lines the panel up perfectly.

Menu 2 hands you `tag_high` and `tag_low` directly, so the secret isn't 256 unknown bits, it's just a 216-bit piece sitting in the middle. And every menu-3 nonce puts the top 128 bits of `k` straight out of the same twister we already cloned, so half of each nonce is known before we even read the signature.

That makes it a straightforward hidden number problem. Grab four signatures from one unit, each with a partially-known (biased) nonce, build the HNP lattice, run LLL, and the 216-bit secret drops out. Submit it for the flag. The crypto here is baby HNP; the real work was the two observations that `panel_value` is self-inverting and that the word accounting lines the panel up.

Flag: `COMPFEST18{b1as3d_n0nc3_mt_r3c0v3ry_lll_hnp_go_brr_727e3a9724b244c1}`
