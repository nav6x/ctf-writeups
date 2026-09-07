# Her Last Pic (TraceBash CTF, forensics)

A forensics challenge built around a PNG with hidden image rows, though the intended path and the path that actually worked diverged at the end.

You get a PNG of a girl and the hint that she left a clue behind. The file looks clean, nothing in EXIF, `strings`, or `binwalk`. The tell is in the PNG header: the declared height is 780, but the actual image data contains 844 rows. PNG stores the dimensions in the IHDR chunk, and a viewer only renders up to the declared height, so anything below that is present in the file but never displayed. Fixing the height field to 844 reveals the hidden strip at the bottom.

The hidden strip held a pastebin link, `pastebin.com/LXh5pz`. Opening it, the page was empty, which sent me down a rabbit hole of LSB, FFT, and XOR on the image for nothing. The link was a decoy whose only job was to point you at pastebin as a platform.

The actual trick was to log into pastebin and search `TBCTF` in the site search, which surfaces the flag paste directly. Not the intended route, admittedly, but the answer is the answer.

The takeaway worth keeping: when a PNG's rendered image looks complete but the file feels too big, check the IHDR height against the real number of decoded scanlines. A mismatch is a classic place to hide data.

Flag: `TBCTF{y0u_w3r3nt_s33ing_th3_wh0l3_p1ctur3}`
