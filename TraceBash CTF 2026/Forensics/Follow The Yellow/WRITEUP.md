# Follow The Yellow (TraceBash CTF, forensics)

The prompt is a photo taken "walking down a street in Japan," with the author unsure whether it "actually meant something." The image is a stretch of Japanese tactile paving, the yellow bumpy tiles you find at crossings and platform edges, and the whole challenge is realizing those bumps are literally Braille and reading them.

The provided `chall.png` is an 857x645 photo of Tenji blocks: a mix of dot/warning tiles and bar/directional tiles on a gray sidewalk. The PNG itself is clean, normal IHDR/pHYs/IDAT/IEND with nothing appended, so there's no file-carving trick here. The one planted clue is a `tEXt` chunk whose `Comment` reads "Even simple recipes have a sequence," which is telling you to read the encoded cells in order.

The hypothesis writes itself once you know the term: "Tenji blocks" literally means Braille blocks, and the dot tiles have dots present in some positions and missing in others. That's Braille, and the "sequence" hint says read the cells left to right, top to bottom.

Getting clean data out of a blurry, perspective-distorted phone photo was the actual work. I ran the image through a small OpenCV/numpy pipeline: upscale and edge-enhance, then build a local standard-deviation "bump map" so the raised dots read as bright spots and the absent ones as grout. A rotation sweep scoring "griddiness" confirmed the dot rows are axis-aligned (only the floor recedes into perspective, the tiles themselves are square-on). Yellow-color segmentation isolated the tactile tiles and found exactly four dot tiles arranged in a 2x2 block, plus the bar tiles. Each tile still had a slight tilt, so I warped each one to a clean 240x240 square with `minAreaRect` and a perspective transform, then read it as a 6x6 dot grid, which is three Braille cells wide by two cell-rows tall, so six cells per tile.

The structural insight is what makes the answer certain despite the noisy extraction. Four tiles times six Braille cells is exactly 24 characters, and "followtheyellowbrickroad" is exactly 24 letters (follow + the + yellow + brick + road). That lines up with the challenge title, the Wizard of Oz phrase, and the "sequence" hint all at once.

Reading each tile's six cells (top cell-row left to right, then the bottom row), and taking the tiles in order top-left, top-right, bottom-left, bottom-right:

```
TL = f o l l o w
TR = t h e y e l
BL = l o w b r i
BR = c k r o a d
```

That spells "follow the yellow brick road."

Flag: `TBCTF{follow_the_yellow_brick_road}`
