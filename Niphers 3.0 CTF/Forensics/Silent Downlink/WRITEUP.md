# Silent Downlink (Niphers 3.0 CTF, forensics)

The challenge hands you a weird WAV that mostly sounds like static. It's a 48kHz stereo recording with distinct signals at the start and end. Spectrograms, LSB checks, raw bytes, and phase analysis all led nowhere, until I noticed three repeating frequencies around 725, 1475, and 1850 Hz. Those match HAMDRM digital SSTV, and the sample sizes matched Mode A, so the "static" was actually an OFDM transmission.

Decoding it with a HAMDRM decoder produced an image, a PNG, despite carrying a `.jp2` extension, and inside it was a 27×27 Aztec code. Decoding that with ZXing gave the flag.

Flag: `$N1PH€RSxTCTF{d1g1t4l_sstv_4zt3c_d0wnl1nk}`
