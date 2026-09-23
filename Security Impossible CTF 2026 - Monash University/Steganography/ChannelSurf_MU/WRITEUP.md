# ChannelSurf_MU (Security Impossible CTF 2026 - Monash University, stego)

We are given a 256x256 RGB image named `intercepted_transmission.png` (file size 1094 bytes). The challenge title "ChannelSurf" points toward steganographic information hiding across individual color planes.

## LSB Steganography Principles

In 24-bit RGB raster graphics, every pixel contains three 8-bit color channels: Red, Green, and Blue. The least significant bit (LSB) of each color byte contributes minimally to the visual appearance of the pixel. Altering the LSB produces color variations imperceptible to human eyes.

Steganographers exploit this property by replacing the least significant bits across pixels with arbitrary payload bitstreams. Payloads can be stored across:
- A single color channel (e.g. Red plane LSB).
- Interleaved across color channels (e.g. sequentially across R, then G, then B).
- In varying bit orders (LSB-first or MSB-first).

## Extracting the Hidden Plane

To analyze PNG bit planes quickly, we use `zsteg`, which automatically tests combinations of color planes, bit arrangements, and pixel orderings:

```bash
zsteg -a intercepted_transmission.png
```

Examining the output:
```text
b1,rgb,lsb,xy       .. text: "sictf{png_lsb_rgb_ch4nn3l_wh1sp3r}\n"
b1,bgr,lsb,xy       .. text: "sictf{png_lsb_rgb_ch4nn3l_wh1sp3r}\n"
b2,r,lsb,xy         .. text: "U\U\U\U"
b4,r,lsb,xy         .. text: "33333333"
```

The payload is embedded cleanly in the combined RGB least significant bit plane (`b1,rgb,lsb,xy`). The bitstream reconstructs ASCII characters directly without additional encryption.

Filtering the output directly for the flag:

```bash
zsteg -a intercepted_transmission.png | grep -ai "sictf{"
```

The tool returns the flag string.

Flag: `sictf{png_lsb_rgb_ch4nn3l_wh1sp3r}`
