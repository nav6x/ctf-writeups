# Unzip Me (TraceBash CTF, misc)

This is a matryoshka archive: an archive nested inside an archive, eight layers deep, where every layer's password is encoded with a different scheme and you have to recognize the scheme each time to get through.

Unzipping the given file gives two things, a `secret.7z` and a password note. The note isn't the raw password, it's encoded, so the first job each round is to figure out which encoding it is and decode it. Decoding it yields the password for the `.7z`, and inside that `.7z` is the same situation again: another `.7z` and another encoded password note. You repeat, and there turn out to be seven layers like this.

The one thing that makes it tractable is that each decoded password also carries its own layer name, so you always know where you are and that you decoded correctly. Without that you'd be guessing whether a decode was right; with it, a successful decode is self-confirming.

The point of the challenge is recognizing encodings by sight, because each layer uses a different one. The ones that showed up were ROT47, EBCDIC, 6-bit, S-record, Intel HEX, Base32768 (which renders as weird CJK-looking Unicode and is the giveaway for that layer), and Base91. Being able to eyeball "that's Intel HEX" or "that's S-record" from the shape of the data is the actual skill being tested.

After layer 7, layer 8 contains a `flag.txt` instead of another archive, and that's the end.

Flag: `TBCTF{br0_kn0w5_3v3ry_3nc0d1ng}`
