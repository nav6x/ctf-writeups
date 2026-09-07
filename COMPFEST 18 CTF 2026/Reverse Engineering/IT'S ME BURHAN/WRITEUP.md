# IT'S ME, BURHAN! (COMPFEST 18, rev)

The hint about Burhan's password is a trap. The obvious login, `burhan` / `burunghantu123`, is a fake admin that the program deletes on startup and swaps out for the real one (class `O`). The real admin password is never stored anywhere. It's rebuilt from a secret seed that only ever leaks as one-way hash "sigils," so wordlists and rockyou will never crack it. You have to reconstruct it.

The actual trick is in the guild screen. When you read your coin and level as Frieren, those two values determine which set of three quests forms the hidden chain, and you have to complete them in the right order. Three sigils each leak part of what the password math needs: the battle sigil, the guild-bulletin sigil (`arsip`), and the export sigil (`ekspor`) together expose the exact seed hashes.

Feed those hashes back into the program's own math to rebuild its internal state, then invert it to recover the admin password. Log in as `burhan` with that password, open menu 13 (`arsip tersegel`), and it prints the flag as permuted hex, which you decode with the same operations. Since the flag is generated per instance from that seed, the suffix differs every time.

Flag: `COMPFEST18{bUR_BuR_BUr_buRh4n_h4Un7s_m3_t!L_t0D4y_Cebvlso5ag5byLSv}` (per-instance suffix)
