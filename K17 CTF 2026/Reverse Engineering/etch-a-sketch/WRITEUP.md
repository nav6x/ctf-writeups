# etch-a-sketch (K17 CTF, rev)

We are given a 64-bit unstripped ELF binary named `etchasketch`. Running it dumps a massive solid block of `#` characters to the terminal.

## Binary inspection

Decompiling the binary shows:
- An array `points` holding packed $(x, y)$ coordinate pairs terminated by a `0xfffe` sentinel.
- A `main` function that iterates through consecutive point pairs, calling `line(x1, y1, x2, y2)` using Bresenham's algorithm.
- Inside `line`, every step calls `dab(x, y)`, which paints every character cell within a square of radius `brush_r` centered at $(x, y)$ onto a 120×82 `canvas`.
- `brush_r` is a global variable located in `.data` at virtual address `0x4020` (file offset `0x3020`), initialized to `10`.

With a brush radius of 10 on a canvas only 120 wide, the strokes bleed into each other and fill the entire drawing area with black blocks.

## Shrinking the brush

Patching the byte at file offset `0x3020` from `10` (`0x0A`) to `0` changes `dab()` to draw only a single pixel per step:

```python
with open("etchasketch", "rb") as f:
    data = bytearray(f.read())

data[0x3020] = 0

with open("etchasketch_patched", "wb") as f:
    f.write(data)
```

Running the patched executable renders a clean single-pixel line art outline across three rows:

```
K17{my_
master
piece}
```

Combining the lines gives `K17{my_masterpiece}`.

Solve: `solve/solve.py`

Flag: `K17{my_masterpiece}`
