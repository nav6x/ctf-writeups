# The 67th Line (COMPFEST 18, crypto)

This one starts as OSINT and ends as an algebraic attack on a custom cipher. The entry point is an Instagram account, `kuliah67`, whose archived posts all begin each line with a word starting in B or O, which reads as binary once you notice it.

Each post has 35 lines, and 35 divides evenly by 5, so I treated it as 5-bit letters rather than ASCII. The caption itself hints "beyond z, two marks belong to archive," so I extended the alphabet past Z with `.` and `/`. Decoding all three posts in order spells `RISTEK.LINK/ASTERGATE`, a redirect into a Google Drive folder holding an `archive.zip`.

Inside are `chall.py`, a large `records.bin` of known plaintext/ciphertext pairs, and one sealed JSON that's the actual challenge. The cipher runs three rounds, each of algebraic degree 2, so the overall map has degree 8. The records are arranged as 9-dimensional affine subspaces, and the key fact is that summing (XORing) the cipher output over a full affine subspace of dimension greater than the algebraic degree gives zero. That vanishing sum is an integral/higher-order-differential distinguisher, and it leaks the 12-bit matrix index used for every byte.

After that the rest falls out of a weakness in the key schedule: it only uses `key[i] >> 8`, so recovering those high bytes gives all the round keys directly, and each low byte drops out from a single known plaintext pair with no brute force needed.

Flag: `COMPFEST18{5e9e8bf77207eca9c6906e80a57aa0e426f18ab8825a7b0f656cfa5d888a81c9_aefbd0dc566889bb}`
