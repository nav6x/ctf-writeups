# Attic (Niphers 3.0 CTF, rev)

The `mx.bin` file is a Vigenère cipher over ordinary ASCII. The repeating tail gave away a key length of 4, and knowing the plaintext would contain "begin" let me lock the shifts quickly. Decrypting it produces a `begin 644` header, but the body isn't classic uuencode, it's xxencode. That alphabet threw me for a moment, but decoding it yields a DOS `.COM` program that masquerades as an `MZ` executable.

The `.COM` asks for an "exorcism key" and runs a tiny whitebox VM: it decrypts 57 bytes with a 12-byte repeating key and only prints if the first five decrypted bytes match `N1PH`. Rather than recover the actual key, I reversed the check math directly: the constraint on the first five bytes gives you the prefix, and the flag format does the rest.

Flag: `$N1PH€RSxTCTF{wh1t3b0x_VM_und3r_a_f4k3_MZ_3x0rc1sed_1985}`
