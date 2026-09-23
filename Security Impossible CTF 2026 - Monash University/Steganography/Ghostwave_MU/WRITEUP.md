# Ghostwave_MU (Security Impossible CTF 2026 - Monash University, stego)

Ghostwave presents a 7.72-second mono WAV audio file named `transmission_ghostwave.wav` sampled at 44.1 kHz with 16-bit PCM encoding. Initial strings, metadata inspections, and phase analysis revealed no clues, indicating that data was embedded inside the spectral structure of the audio signal.

## Spectrogram Analysis

Audio steganography often conceals text or images directly in the frequency domain. When viewed through a Short-Time Fourier Transform (STFT) spectrogram, intensity variations across frequency over time paint recognizable visual patterns.

Using SoX (`sound exchange`), we render a high-resolution spectrogram:

```bash
sox transmission_ghostwave.wav -n spectrogram -x 2000 -y 800 -z 90 -o spec.png
```

Opening `spec.png` reveals visual text rendered across the frequency axis.

## Decoding the Spectral Structure

Examining the spectrogram closely dispels a common assumption: this is not large freehand text or an image painted with tools like Coagula. Instead, the signal consists of **7 discrete, parallel sinusoidal carrier frequencies**:
- Tone 1: ~991 Hz
- Tone 2: ~2153 Hz
- Tone 3: ~3316 Hz
- Tone 4: ~4479 Hz
- Tone 5: ~5685 Hz
- Tone 6: ~6848 Hz
- Tone 7: ~8010 Hz

Notice that the carrier tones have an exact, uniform spacing of approximately 1163 Hz between 1 kHz and 8 kHz. Each carrier tone turns on and off in synchronized time slices, acting as the 7 vertical rows of a classic **5x7 dot-matrix font**.

Attempts to demodulate the signal as 7-bit ASCII or FSK frequency-shift keying produce gibberish. The tones do not encode digital byte values; rather, they form an optical dot-matrix image designed to be read visually as glyphs.

## Visual Extraction and De-noising

In the generated spectrogram image, the carrier tones appear as bright yellow pulses against a dark background. Because yellow corresponds to high red and green values while background noise has low green intensity, we isolate the green channel to cleanly binarize the dot matrix:

```python
from PIL import Image

img = Image.open("spec.png")
g_channel = img.split()[1]
thresh = g_channel.point(lambda p: 255 if p > 160 else 0)
thresh.save("clean_matrix.png")
```

Reading the resampled dot-matrix glyphs visually across the timeline:

```text
S I C T F { F R E Q U E N C Y _ G H O S T _ H E A R S _ A L L }
```

A notable pitfall during the live competition was over-guessing leetspeak: because dot-matrix glyphs render letters with sparse dots, an `E` can resemble a `3`, an `A` can resemble a `4`, and an `O` can resemble a `0`. However, the challenge text is plain English words. Converting the uppercase transcript to the lowercase competition format yields: `sictf{frequency_ghost_hears_all}`.

Flag: `sictf{frequency_ghost_hears_all}`
