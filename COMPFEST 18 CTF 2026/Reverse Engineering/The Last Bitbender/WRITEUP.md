# The Last Bitbender (COMPFEST 18, rev)

`chall.exe` is a 3KB PE32 whose real payload is x86-64. It gets there with Heaven's Gate,
four times, and each mode flip decrypts the next stage. The service hands you a random
16-byte block and wants `F(block)` back, so the whole challenge is: recover `F`.

## The pivot

`main` is boring and tells you everything:

```
VirtualAlloc(0, 0x2a2, MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE)
memcpy(rwx, 0x402000, 0x2a2)
push out ; push in ; pop ecx ; pop edx ; call eax
memcmp(out, 0x4022b2, 0x10)
```

So the blob is a leaf function, `ecx` = 16-byte input, `edx` = 16-byte output, and the
binary ships its own test vector at `0x4022a2` / `0x4022b2`. That vector is the oracle: you never need to run the thing on Windows.

The blob starts `53 56 57 55` (`push ebx/esi/edi/ebp`) and then:

```
31 c0              xor eax, eax
66 8c c8           mov ax, cs
83 c0 10           add eax, 0x10
50                 push eax
e8 00 00 00 00     call $+5
83 04 24 05        add dword [esp], 5
cb                 retf
```

`cs + 0x10` is selector `0x33` on WOW64, the 64-bit code segment. Everything past
blob+0x17 has to be disassembled as x64. Disassemble it flat as 32-bit and you get
garbage that still *looks* like code, which is the trap.

## The chain

Four stages, alternating mode, each one XOR-decrypting the next with an LCG keystream
and then `retf`-ing into it. A scratch table at blob+0x282 holds the in-ptr, out-ptr and
the 128-bit state `(A, B)`; that's the only thing carried across mode flips.

| stage | mode | at | LCG | decrypts |
|---|---|---|---|---|
| 1 | x64 | +0x17 | mult `9e6c63c6a3c4b1d1`, add `2545f4914f6cdd1d`, `>>56` | 0xC2 @ +0xD4 |
| 2 | x86 | +0xD4 | mult `2c9277b5`, add `ac564b05`, `>>24` (32-bit!) | 0x9A @ +0x196 |
| 3 | x64 | +0x196 | mult `2545f4914f6cdd1d`, add `9e6c63c6a3c4b1d1`, `>>56` | 0x52 @ +0x230 |
| 4 | x86 | +0x230 | none | writes the output |

Stage 3's LCG is stage 1's constants with mult and add **swapped**. Miss that and stage 4
decrypts to noise while stages 1-3 look perfect.

Stage 2 is the fun one, 64-bit arithmetic hand-written in 32-bit registers:

```
mul ecx ; add eax, [esi+0x28a] ; adc edx, edi      ->  A = A.lo32 * B.lo32 + A
shld ecx, edx, 13 ; shld edx, eax, 13              ->  B = rol64(B, 13)
```

## F

```python
A, B = struct.unpack("<QQ", block)
A ^= 0xa6f1c0d93b5e2748

A = ((A & 0xffffffff) * (B & 0xffffffff) + A) % 2**64
B = rol64(B, 13)
A ^= B

B = rol64((B + A) % 2**64, 29)
B = (B * 0xff51afd7ed558ccd) % 2**64
A = rol64((A + B) % 2**64, 17)

out = pack("<QQ", A ^ B, (A + B) % 2**64)
```

No key material anywhere, no lookup tables. It's a pure ARX-ish mixer, and whether it
inverts doesn't matter since the server only asks forward.

Checks against the shipped vector:
`9c41e07db2f5361a8ad30c47e961b5f2` -> `023a3db6ab0ec7efd2babd484c91f80f`.

## Dead end

Plan A was to skip reversing entirely and just emulate the blob in Unicorn. Unicorn has no
wheel for Python 3.14 and the source build failed, and emulating Heaven's Gate needs a
hand-built GDT anyway. That's two problems for what turned out to be ~200 bytes of real
code across four stages. Peeling it statically with capstone was faster than fighting the build.

## Run

```
pip install capstone
python3 solve.py            # or: python3 solve.py HOST PORT TOKEN
```

`solve.py` does the whole walk, parses the PE, dumps `main`, peels all four stages and
prints each one's disassembly as it decrypts, self-tests against the embedded vector,
then answers the service.

```
COMPFEST18{0nly_th3_av4t4r_m4st3r3d_4ll_th3m_b1ts_os3ORnzC9zLOuec2}
```

Flag: `COMPFEST18{0nly_th3_av4t4r_m4st3r3d_4ll_th3m_b1ts_os3ORnzC9zLOuec2}`
