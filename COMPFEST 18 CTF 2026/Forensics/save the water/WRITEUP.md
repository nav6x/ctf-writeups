# save the water (COMPFEST 18, forensics)

`public.7z` is one 181MB pcap. The whole chain hangs off a covert channel that
puts nothing in the bytes: 280 identical 6-byte `BEACON` pings where the data is
in the ~1s vs ~2s inter-packet gaps. Decode that and you get 34 of the 66
characters of the zip password. The other 32 the questionnaire hands you at Q6. They exist nowhere in the capture,
which is why nobody solved this before the nc service went up.

Everything else is layer peeling.

## the capture

Four things in it, three of them useful.

65k ICMP echo requests carry `EXFIL` + 1400-byte chunks. Concatenate in order,
strip the 5-byte magic, and you get a 45MB `MDMP`, a procdump of a python
process. Two HTTP GETs pull `video.enc` and `private.676767`. The 2.6k UDP
packets to :1234 are an RTP stream with SSRC `0x82e7d63a`; the stream itself is
a news clip with the SPS/PPS stripped, so it will not decode without you
rebuilding them. Don't bother, since only the SSRC is ever asked for.

`resource.dat` (14MB of generated config blocks, 186k base64 `REM` lines that
decode to verified-random bytes) and the 176MB `Installer.exe` (stock unmodified
Electron) are both pure bloat.

## the beacons

```python
bits = [0 if stamps[i+1] - stamps[i] < 1.5 else 1 for i in range(len(stamps)-1)]
```

280 beacons, 279 gaps, MSB-first, lands on exactly 34 bytes:

```
d0nt_ruN_th3_m4lw4r3_y4hh_82117caa
```

## key out of the dump

The script is a python process so the AES key and IV are still sitting in the
heap as `PyBytesObject`s. Scan for an 8-byte little-endian size field with
printable data 16 bytes later, NUL-terminated. That leaves 3 candidates at
length 32 and 14 at length 16, so rather than being clever just try all 42
combinations against `video.enc` and keep whichever produces `PK\x03\x04`:

```
bd7bf788d62bdec9c219316da4487314 / y0u_g0t_tr4pp3d!
```

Decrypt, strip PKCS7, unzip, and you get a phone video of someone holding up a
piece of paper.

## the paper

This ate more time than it should have. The note is crumpled, the lighting is
bad, and `1` followed by `3` written close together reads convincingly as `R`.
I stacked 140 ECC-aligned frames to get a clean image and still submitted
`160R1115`, then `160131115`, before the `Format: decimal digit` line made it
obvious there were no letters in it:

```
16031115
```

That's the password on the inner zip. The outer one is the beacon string plus
the Q6 suffix, and the chain finishes:

```
private.676767 --(beacon+suffix)--> fastAI.zip --(16031115)--> fastloader.exe
```

NSIS installer, Electron app inside, obfuscated `main.js` that drops
`62.60.226.198/uploads/b1bfea2e28e542199321fe20ca1737f1.exe` and exfils
screenshots over Telegram. None of that is asked about.

## q10

> What are the hexadecimal values of the starting point (Offset) and the data
> block length (Size) required? `Format: Offset_Size`

The values are the NSIS overlay: parse the first header for
`\xef\xbe\xad\xdeNullsoftInst`, offset is the match minus 4, size is the
`length_of_all_following_data` dword at +24.

```
0x9600 / 0x46ecd9d
```

I had these about twenty attempts in and then spent three thousand more looking
for different numbers, because `0x9600_0x46ecd9d` and `9600_46ecd9d` are both
rejected. The checker wants each side zero-padded to 8 hex digits:

```
00009600_046ecd9d
```

Case doesn't matter, `0x` breaks it, width is everything. Nothing states this.
Q3 gives you a literal `xx-xx-xx-xx` template; Q10 gives you words.

Lesson for next time: the value space is large but derivable, the format space
is ~60 renderings and unguessable. Sweep the small one first.

## q11

`resources/elevate.exe` in the Electron app is the standard electron-builder UAC
helper. Version resource says `Johannes Passing`.

## flag

```
COMPFEST18{b0r05_41r_vv0y_j4n64n_p3cu7_p3cu7_41_mu1u_dfmabfbfdadf}
```

Indonesian leetspeak: *boros air woy, jangan pecut-pecut AI mulu*, "you're
wasting water, oi, stop flogging the AI all the time". The title is about
datacenter cooling.

## running it

```
pip install pyzipper pycryptodome
python3 solve.py public.7z
```

Needs `7z` on PATH for the NSIS and inner-archive extraction (py7zr chokes on
the BCJ2 filter). Takes about 20 seconds, four connections to the nc. Three of
them are the Q10 format retries, left in because that's what actually happened.

Flag: `COMPFEST18{b0r05_41r_vv0y_j4n64n_p3cu7_p3cu7_41_mu1u_dfmabfbfdadf}`
