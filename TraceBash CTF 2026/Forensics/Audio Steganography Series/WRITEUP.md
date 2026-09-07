# Audio Steganography Series (TraceBash CTF, forensics)

Two related audio-crypto challenges. Both hide data in a musical track, and in both the real puzzle is figuring out which property of the audio actually carries the secret: the notes themselves, their frequencies, the amplitude, or the phase.

Challenge 1, Harmonic Cipher, was 500 points, flag `TBCTF{h4rm0n1c_fr3qu3nc13s_4r3_m3l0d1c}`. Challenge 2, Phase Shift, was also 500, flag `TBCTF{Ph4s3_M0dul4t10n_1s_Tr1cky_!992}`.

## Harmonic Cipher

The flavour text talks about a "crypto-acoustic artisan" and says true listeners will "hear more than just music". You get `ciphertext.bin` (39 bytes, "the vault") and `melody.wav` (8 seconds, mono, 16-bit, 44.1 kHz).

The WAV is eight seconds and contains eight pure tones, one per second, with short gaps between them. I found the note boundaries from the amplitude envelope and ran an FFT on each segment to read its dominant frequency. The eight came out as 440, 494, 523, 587, 659, 698, 784, and 880 Hz, which are the notes A4, B4, C5, D5, E5, F5, G5, A5, an ascending C-major scale. So the melody really is "just music". The hint "hear more than just music" means: don't read the notes as the letters A B C D E F G A, read them as their frequencies.

To decrypt the 39-byte vault I tried a range of key derivations and the one that worked was each frequency reduced modulo 256, used as a repeating 8-byte XOR key. That is `[440,494,523,587,659,698,784,880]` mod 256, which is `[184, 238, 11, 75, 147, 186, 16, 112]`. XORing the ciphertext against that repeating key gives the flag, and the decrypted plaintext even confirms the trick by spelling out "harmonic frequencies are melodic".

Things that looked tempting but were decoys: reading the notes as the letters ABCDEFGA, using MIDI note numbers (69, 71, 72...), LSB steganography on the samples, hunting for hidden tones or extra spectral peaks, and looking for appended data or extra WAV chunks.

## Phase Shift

This one is much harder and has three independent layers: a key derived from the amplitude, a ciphertext hidden in the phase, and an AES step tying them together. You get `challenge.flac`, 8 seconds, mono, 16-bit, 44.1 kHz, lossless.

The FLAC's Vorbis comment is the Rosetta Stone. It reads, roughly, "Phase 1 Complete. Tuned strictly to the notes. Format your findings with hyphens, and secure them with a 256-bit hash. We analyzed a 16K sample block." Decoded, that maps to four instructions: the answer involves musical notes, you join your findings with hyphens like `X-Y-Z`, you hash them with SHA-256 (but that hash is a key, not the flag), and you analyze the first 16384 samples. You read it with `metaflac --list` or by parsing the Vorbis comment block directly.

The key comes from the audible melody, which is a four-chord progression of about two seconds each. An FFT per two-second region reads the dominant notes: 0 to 2 s is A, C, E (A minor); 2 to 4 s is C, E, G (C); 4 to 6 s is F, A, C (F); 6 to 8 s is G, B, D (G). So the findings are `Am-C-F-G`, and the AES-256 key is `SHA-256("Am-C-F-G")`. The wrong turn a lot of people take here is submitting that digest as the flag; it's the decryption key.

The ciphertext is in the phase, which is the "look beyond the amplitude" part. The first 16384-sample block was synthesised purely from sine waves placed exactly on the FFT bin grid, so its spectrum is purely imaginary and every frequency bin has phase of either +90 or -90 degrees up to about 1.5 kHz. The sign of each bin's phase is one bit of hidden data. The bit stream is a 32-bit length field (value 512) followed by a 512-bit payload, which is 64 bytes of ciphertext. I found the right window by scanning candidate FFT lengths for the one where the low-frequency bins are all quantised to plus or minus 90 degrees, and only L = 16384 gave a perfect match, matching the metadata's "16K sample block", with the clean phase region running from bin 1 to bin 544. Concretely, take the FFT of the first 16384 samples, read one bit per bin from the sign of the imaginary part over bins 1 to 544, skip the first 32 length bits, and pack the remaining 512 into 64 bytes.

That 64-byte payload is `IV (16 bytes) || ciphertext (48 bytes)`, decrypted with AES-256-CBC under the note-hash key, with padding that's just trailing newlines. Strip the newlines and you have the flag.

The reasons it's called tricky: there are two channels carrying two different things (amplitude gives the key, phase gives the ciphertext, and you need both); the hash is a key and not the flag; a block whose FFT phases are all exactly plus or minus 90 degrees is the signature that it was built from sines and that the sign carries bits, which is the literal "phase shift"; and the metadata is effectively the spec, with each phrase mapping to one step. Dead ends I burned first: treating the 64-byte phase payload as plaintext or a bitmap, Bender phase-coding near the Nyquist bin, single-byte and repeating-key XOR, decompression attempts (zlib/gzip/bz2/lzma), LSB stego and FLAC padding blocks, and submitting the raw SHA-256 as the flag.

Tooling: `soundfile`/`numpy` for reading and FFT, `metaflac` for the Vorbis hint, `pycryptodome` for the AES, and `hashlib` for the key.

Flag: `TBCTF{h4rm0n1c_fr3qu3nc13s_4r3_m3l0d1c}`, `TBCTF{Ph4s3_M0dul4t10n_1s_Tr1cky_!992}`
