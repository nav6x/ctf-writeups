# META GOT SOLID FLAGS (Niphers 3.0 CTF, rev)

The `enc` binary is honest: it takes your input, prepends a 4-byte length, pads it, and runs every word through 56 chained functions from `liblib.so`. The `dec` binary is supposed to do the exact inverse, but it doesn't.

The trap is inside `dec`'s ELF headers: there are **two `PT_LOAD` segments mapping the same virtual address `0x1000`**, which is exactly where `DT_JMPREL` points. The loader takes the last one, so all the `dec_*` GOT slots bind to the wrong functions, which is why running it just complains that the length is corrupted and the decryption is abnormal. There's also a decoy section named to look like `.rela.plt` with a broken `sh_entsize`, purely to make `readelf` and `nm` misbehave, and `liblib` itself detects being loaded from a custom harness and prints a "DON'T WASTE YOUR TIME" banner, so there's no point reversing the library.

The fix is small once you see it: flip the duplicate `PT_LOAD` (program-header index 15) to `PT_NULL` so the genuine `.rela.plt` mapping stays alive, then `chmod` and run the patched `dec` on the ciphertext.

Flag: `$N1PH€RSxTCTF{n0W_d0_Y0u_r3M3M83r_wh0_y0u_4r3_wh47_y0u_4R3_m34N7_70_D0_b9ab326df6}`
