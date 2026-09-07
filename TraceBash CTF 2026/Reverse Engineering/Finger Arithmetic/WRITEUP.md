# Finger Arithmetic (TraceBash CTF, rev)

You get a 64-bit Linux ELF that asks for a 32-character key and prints success if you get it right; the key is the flag. No source, no network service, everything lives in the validation routine. The binary needs a very new glibc (2.38), so it only runs cleanly under Ubuntu 24.04, which meant Docker with amd64 emulation for the final ground-truth check.

The binary isn't stripped, so the structure reads straight off the disassembly. `main` applies four classes of check to the 32-byte input: length must be exactly 32; the first four bytes must be `TBCT` (`0x54434254`); byte 5 must be `{` (`0x7b`); and then the real puzzle, `validate_checksum_v2`. So the flag opens with `TBCTF{` before the interesting part even starts.

The checksum reads the 32 input bytes as eight little-endian 32-bit words `d0..d7` and folds them into a running value with an alternating add/xor/subtract chain:

```
v0 = d0 + 0x11223344
v1 = d1 ^ v0
v2 = d2 - v1
v3 = d3 ^ v2
v4 = d4 + v3
v5 = d5 ^ v4
v6 = d6 - v5
v7 = d7 ^ v6
```

Each intermediate `vN` is handed to `compare_hand_png_i32(vN, embedded_png_N, size)`, and all eight must match. The key property is that the chain is fully invertible: if you learn every `vN`, you can walk backwards to every `dN` and recover the 32 input bytes. So the whole challenge reduces to a single question, what integer does each of the eight embedded images represent?

That's what makes it unusual. The targets aren't stored as numbers, they're stored as pictures of hands. `compare_hand_png_i32` doesn't compare integers; it re-renders the candidate value into an image and compares that image pixel by pixel against the embedded PNG, allowing about 100 pixels of anti-aliasing slack. A 32-bit value is split into its four bytes, each byte drawn as one hand whose eight fingers (thumb plus seven) are raised or lowered by the eight bits, binary finger-counting, and the four hands are laid out in a 2x2 grid to make a 256x256 PNG.

If the rendering were plain you could just read the fingers off and be done, and the author defends against exactly that. Every hand also gets a rotation, hue shift, stroke colour, and per-finger jitter derived by hashing the *full* 32-bit value through a MurmurHash-style mixer seeded with `0xDEADBEEF`. Change one byte and all four hands rotate and recolour differently, so you can't isolate individual bytes; you have to guess the whole 32-bit value, render it, and check whether the picture matches.

The attack follows the invertible chain. Reproduce the renderer exactly (the challenge ships an open helper, `hand_png_helper.cpp`, built on lodepng) so you can test candidates offline without running the ELF, then go word by word. You already know `v(N-1)` from the previous step, each word `dN` is four ASCII characters of the flag (a small search space), so for each candidate you compute `vN` from the chain, render it, and compare to image `N`; an exact zero-pixel match reveals `dN`. The anchor that bootstraps everything is that `d0 = "TBCT" = 0x54434254`, so `v0 = d0 + 0x11223344 = 0x65657598`, confirmed against the first image.

Naively this is too slow: the stock renderer takes about 4.8 ms per candidate, and a 4-character word over just lowercase is 26^4 ≈ 457k candidates, over half an hour per word. Three changes in a rewritten solver make it practical. The stock code called `sin`/`cos` per finger inside the per-pixel loop (~330k trig calls per render), but those angles are constant per hand, so precompute them once. The match threshold is only 100 differing pixels out of 65,536, and a wrong value's hands are rotated differently so differences pile up immediately, so render-and-compare pixel by pixel in a quadrant-interleaved order (touching all four hands early) and abort the moment the diff count passes 100, which kills wrong candidates after a few hundred pixels instead of 65,536. Finally, split the outer loop across all cores. That drops effective work to well under 60 microseconds per rejected candidate, about 110 seconds per word over the full `[a-z0-9_]` charset, with every correct word matching at exactly diff 0.

Peeling the chain off four characters at a time gives the words `TBCT`, `F{ju`, `75u5`, `_n_d`, `34d_`, `3nd5`, `_4w4`, `17!}`. The flag is leetspeak: reading `3=e, 4=a, 5=s, 7=t, 1=i` it says "dead ends await." The last word needed the full printable-ASCII charset because of the `1`, `7`, and `!`. Feeding the key to the real ELF under Ubuntu 24.04 confirms it: "Correct!"

Flag: `TBCTF{ju75u5_n_d34d_3nd5_4w417!}`
