# Bliss II (BushBash CTF, forensics)

The sequel to Bliss I, and the twist is beautiful: the file is a 300x200 field of pure black-and-white noise, every statistical test says it's random, and that's exactly the point, because a QR code drawn at 1 pixel per module is statistically indistinguishable from white noise. The symbol was sitting in plain sight the whole time. Both its finder patterns and its alignment pattern were painted over with noise, so the only function pattern left to locate it by is the timing pattern, which the hint spells out.

Flag: `bushbash{///hillside-errand-lateral}`.

## Recon

The PNG is 300x200, greyscale, and genuinely 1-bit: the only pixel values are 0 and 255, with white appearing about 52.5% of the time. The XMP again names Affinity 3.2.3. Because Bliss I lived inside a PNG, I specifically checked the container for the height-field trick, but the IDAT decompresses to exactly 200 scanlines with ordinary adaptive filtering and nothing after IEND. There's nothing in the container; the payload is in the 60,000 bits.

## Everything that doesn't work, and why that matters

This part is the actual solve, because establishing that the image is statistically perfect noise is what points you at the answer. I ran lattice sub-sampling (every stride and offset, both polarities, template-matched against the 7x7 finder) and got only chance-level matches. Global statistics showed no periodic FFT structure, no excess block variance, and no even/odd row or column parity channel. Shifted-copy and autostereogram correlation found no repeated region. Run-length analysis came out essentially geometric, which immediately rules out Manchester coding (Manchester forbids runs longer than 2, but the max run here is 18). Line-coding transforms (XOR-left, XOR-up, cumulative XOR, NRZI) produced nothing. The frequency domain looked like pure noise. Reshaping to wrong line lengths for a "broken sync" idea, modular stride permutations for a "sampling clock" idea, extended 1-D strides across every QR size, and a hidden-module-grid FFT all came back flat, with observed standard deviations matching the iid prediction almost exactly. A combined timing-plus-alignment template search across versions 2 to 40 also got zero hits, and that near miss is the pivot: it failed only because the alignment patterns had also been erased, dragging every score below threshold. Finally, a PRNG-seed-from-timestamp hypothesis (image = QR XOR PRNG seeded by the metadata time) found nothing, which was always weak because Affinity produced the file, not a Python script.

## The insight

A QR code at 1 pixel per module is statistically identical to white noise. Its modules are pseudo-random by construction, so density, variance, spectrum, autocorrelation, and run lengths all look like noise. That's precisely why every test above came back clean, and it means the QR had been in the image all along, invisible to statistics. Paired with the series' theme (Bliss I painted out the finders), the hint becomes completely literal: "Uncovering it is all a matter of timing" means find it by its timing pattern, because that's the only function pattern the author left.

## The tell: longest alternating runs

A QR timing pattern is a strictly alternating line of modules, so for every pixel I computed the length of the alternating run ending there, once per row and once per column. Two 21-long alternating runs showed up, one along row 113 and one down column 67, meeting at the corner (113, 67). A single 21-run in 60,000 pixels is already improbable; two intersecting at a right angle is a QR timing cross.

## Locating and sizing it

I rebuilt the template with timing patterns only (row 6 and column 6, dark on even indices, spanning indices 8 to n-9) and demanded a perfect match, sliding over every position, four rotations, two polarities, and versions 1 to 40. It matched perfectly at r0=107, c0=61 for versions 2, 3, and 4, but not version 5, because the v5 template needs the alternating run to continue to index 28 and it breaks at 27. So the symbol is exactly version 4, 33x33. With 34 exact modules matched, the false-positive probability is about 2^-34, so this is certain rather than suggestive. (Version-1 templates fire all over by chance and can be ignored.) The polarity told me dark module maps to black pixel, standard orientation, no inversion. The symbol occupies rows 107 to 139 and columns 61 to 93, and zxing-cpp on that raw block gets zero hits, as expected, because the three finders are noise.

## Format info and decoding

For a 33x33 symbol the format bits sit at row 8 and column 8 with a mirrored copy, all outside the 7x7 finder blocks, so they survived. Matched against segno references, both copies agree perfectly on version 4, EC level L, mask 4. The alignment block itself reads as noise, which confirms the earlier diagnosis: this time the author erased the alignment pattern in addition to the finders, which is exactly why the combined timing-plus-alignment search missed the symbol.

To decode, I built the version-4 function map (finders at the three corners, separators, both timing lines, alignment at rows/cols 24 to 28, format info, dark module at (25,8), and no version-information block since that only starts at v7), pasted reference values over every function module, traversed, unmasked with mask 4, and RS-decoded. The v4-L layout is one block of 100 codewords, 80 data plus 20 EC, over 807 data modules (800 codeword bits plus 7 remainder bits, correct for v4). RS reported zero errata: `bushbash{///hillside-errand-lateral}`. Running an off-the-shelf zxing decoder on the restored symbol returned the same string. Zero Reed-Solomon errata means all 807 data modules were recovered pixel-perfect with no error correction consumed at all, and two independent decode paths agreeing with zero corrections is about as conclusive as verification gets.

## Takeaway

The timing pattern is a QR locator of last resort. When the finders and alignment patterns are gone, a perfect timing-only match of 2(n-16) modules is astronomically specific (2^-34 for version 4) and needs no finders, no alignment, and no format info to fire. The cheap way to spot one, by eye or by script, is to build longest-alternating-run maps per row and per column and look for two long runs meeting at a corner. The misdirection in this challenge is good, too: "snow" and "timing" together strongly suggest analog TV sync, sampling clocks, or PRNG seeds, which are exactly the rabbit holes the failed tests catalogue.

Flag: `bushbash{///hillside-errand-lateral}`
