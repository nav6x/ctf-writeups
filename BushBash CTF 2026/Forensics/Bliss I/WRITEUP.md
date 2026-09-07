# Bliss I (BushBash CTF, forensics)

A QR code is composited into the sky of the Windows XP "Bliss" wallpaper, disguised as a cloud. It's blurred, rotated a few degrees, squashed so the modules aren't square, and its three finder patterns have been painted over with noise so no scanner will look at it twice. The whole challenge is reconstructing a readable symbol from what survived.

Flag: `bushbash{bucolic_green-hills}`.

The short version of the solve: the timing patterns, the alignment pattern, and the format information all survived. You recover the grid geometry, deconvolve the blur, read the format bits to get the version, error-correction level, and mask for free, paste the finder patterns back in from a reference, and decode by hand. The extraction ends up about 1% noisy, which is just past what Reed-Solomon can correct, so the last step is a targeted erasure search.

## Recon

The PNG is 3840x2160, 8-bit RGB, with an XMP block naming the producer as Affinity 3.2.3 and nothing appended after IEND, no rogue chunks, and no PNG height-field trick. Everything is in the pixels. The Affinity producer string is a useful early signal: this was built by hand in an image editor, so expect a visual embedding (a layer, a blur, a transform) rather than a scripted XOR or PRNG stream.

There's a visibly wrong rectangular patch of blocky noise in the sky. It's easiest to pull out on the red channel, because the sky is dark red and the cloud is white, giving maximum contrast. To get an exact bounding box I masked on local standard deviation (the patch is the only high-frequency thing in an otherwise smooth sky), closed and then eroded the mask back, took the largest connected component, and fit a rotated rectangle. That gave a 421.4 x 228.7 px rectangle rotated about 2.9 degrees, aspect ratio 1.843, so the modules are not square. One trap here: if you close the mask without eroding back, the rectangle inflates by about 7 px per side and the sampled matrix comes out with a solid border of dark modules. A uniform border in an extracted QR matrix is almost always a geometry artifact, not data.

## How many modules

I tried three ways to count modules. An FFT of the edge-density profile suggested about 30 cycles per axis but 29, 30, and 31 were all close, so it was ambiguous. A peak-spacing histogram was inconclusive, with the horizontal gaps smeared. The decisive method was circular vector strength: collect every black-to-white transition position along an axis, and for each candidate module count measure how tightly those positions cluster modulo the implied pitch (the magnitude of the mean of exp(2j*pi*P/(L/n))). That pointed cleanly at 29 x 29 with 14.52 x 7.90 px modules, and 29x29 is QR version 3. This phase-coherent summation is worth stealing as a technique: it's far more selective than an FFT magnitude peak when you have few periods and noisy edges.

Zooming the lower-right quadrant confirmed it: a small white 3x3 with a dark centre dot, which is the light ring and dark centre of a 5x5 QR alignment pattern. Its measured centre, as a fraction of the rectangle's own edge vectors, landed within 0.4% of where a version-3 alignment pattern belongs (module 22 of 29). So this is definitely a QR version 3, and from here it's decoding rather than guessing.

## Recovering a clean matrix

Sampling the grid shows noise in all three finder corners: the author painted noise over the three 7x7 finder blocks, while timing, alignment, and format info stayed intact. That's the whole challenge.

Three problems stand between the pixels and a clean matrix: the sky gradient, the blur, and sub-pixel grid alignment. For the background, don't high-pass it, because a global high-pass puts a bright halo just inside the block edge and flips the border modules. Instead fit a cubic surface to the sky pixels outside the block and subtract it. For the blur, note that because the modules are 14.52 x 7.90 px the blur is much worse vertically in module units, so model the per-cell observations as a separable product OBS = Ky . X . Kx^T, where each kernel entry is the fraction of a module's ink landing in an observed cell (built numerically at 64x subsampling with a Gaussian whose sigma is in module units), and invert it with two small Tikhonov-regularised solves. For geometry, use the timing and alignment patterns as ground truth: score a candidate corner placement by how well the recovered timing and alignment modules match their known values, and run coordinate descent on the four corners, stepping from 3.0 px down to 0.25 px. That drove timing-plus-alignment agreement to 51 out of 51, so the geometry is certain.

Things that didn't help: greedy binary model fitting plateaued well above the noise floor because the cloud texture behind the code adds real variance the model can't represent (though it did consistently prefer mask 2, which was later confirmed correct); local adaptive thresholds were worse than a single global median under this near-uniform illumination; and per-channel variants gave no improvement.

## Format information, the skeleton key

The 15 format bits live at row 8 and column 8, outside the 7x7 finder blocks, so they survived. Rather than implementing the BCH decode, I generated all 32 possible format strings with segno and compared, which matched version 3, EC level L, mask 2 (copy 1 at Hamming distance 0). This is the key idea of the whole challenge: the format information is BCH-protected and sits outside the finders an attacker is most likely to destroy, so reading it hands you version, EC level, and mask for free, after which the finder patterns are just boilerplate you paste back from any reference encoder.

## Decoding

I used a hand-rolled decoder, self-tested against a segno-generated symbol first: apply the function-module mask for every version-3 function module, do the standard boustrophedon traversal two columns at a time right to left skipping column 6, unmask with mask 2, and RS-decode with RSCodec(15, fcr=0, prim=0x11d, generator=2). The v3-L layout is one block of 70 codewords, 55 data plus 15 EC.

Plain RS decode failed, and the error budget explains why: with 51/51 timing and alignment correct, 15/15 on format copy 1 and 14/15 on copy 2, that's roughly a 1.2% module error rate, about 8 bad modules across 641 data modules, and RS-15 only corrects 7 errors. Just past the limit. Chase bit-flips and brute-forcing the least-confident bits all failed. What worked was an erasure combination search: rank codewords by how close their modules sit to the binarisation threshold, take the 18 least reliable, and try every subset of size 3 through 11 as an erasure set, validating that the decoded payload actually parses and is printable. Erasing 7 specific codewords decoded to bushbash{bucolic_green-hills}.

The verification is satisfying: the decoder reported 11 errata, which is 7 erasures plus 4 residual errors, and 2e + f = 2(4) + 7 = 15 is exactly the capacity of RS(70,55), so the decode sits precisely at the theoretical limit. Cross-checking against a clean re-encode of the recovered string, codewords 0 through 30 (the entire message segment) match byte for byte; later codewords diverge only because the original encoder used different padding than segno.

A few traps worth remembering. A "successful" RS decode with the maximum number of erasures is meaningless, because with 15 erasures and 15 parity symbols the decoder always finds some solution, so always validate the decoded content (my first sequential-erasure run "succeeded" with an empty payload). Never diff modules against a re-encode, because padding bytes legitimately differ between encoders; compare codewords instead. Don't high-pass a smooth gradient. And local adaptive thresholding isn't automatically better; under uniform lighting it was measurably worse.

Flag: `bushbash{bucolic_green-hills}`
