# Backrooms (COMPFEST 18, rev)

This is a 68MB Bevy (Rust) game, and I watched people burn hours reversing it. The whole challenge collapses to one observation: there's no `bevy_ui` or text plugin loaded, so the game literally cannot draw a flag on screen. That forces the flag to be baked into the level geometry instead, which is exactly where it turns out to be.

Grepping for the flag directly got nothing, no XOR, no base64, nothing. But sitting in `.rdata` at `0x142f3f978` is a random-looking 60-byte blob that a `lea r10` at `0x140005284` points straight at. That's the payload.

The decoder is a glibc-style LCG: seed `0xa3f1924d`, multiply by `0x41c64e6d`, add `0x3039`, with a rolling key that starts at `0xdb` and updates each step (add `0xf3`, rotate left by 7, subtract `k mod 7`), then XOR against the high byte of the state. Running it produces pure garbage, not ASCII, and that's the trap. The decoded bytes were never meant to be text. Each byte gets split into its 8 bits, so 60 bytes is really 480 bits.

The spawn loop then drops those 480 bits as floor tiles in a 4×120 grid. So it's a bitmap you're meant to read from above. The "I saw a place" hint in the game is literal. Laying the 480 bits out as 4×120 and reading the tiny pixel font, the flag is right there.

Flag: `COMPFEST18{HE_IS_20_YEARS_OLD}`
