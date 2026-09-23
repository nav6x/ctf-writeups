# XorGate_MU (Security Impossible CTF 2026 - Monash University, rev)

The challenge supplies an unstripped 64-bit Linux executable named `keypad`. The program prompts the user for an access code and terminates with "Access Denied" if validation fails. Our objective is to reverse-engineer the binary to extract the expected password.

## Binary Inspection and Control Flow

Running `file` and `checksec` on `keypad`:
- Arch: `ELF 64-bit LSB executable, x86-64`
- Symbols: `not stripped`
- Protections: Canary found, NX enabled, No PIE

Because PIE is disabled and symbol names are intact, we disassemble `main` using `objdump`:

```bash
objdump -d -M intel keypad
```

Tracing `main` in assembly:
1. The program calls `puts("Enter access pin:")` followed by `fgets(buf, 0x40, stdin)`.
2. It strips the trailing newline character by replacing `\n` with a NUL byte.
3. It checks `strlen(buf) == 35` (`0x23`). If the string length does not match 35, it jumps straight to the failure branch.
4. A loop counter `i` is initialized to 0.
5. In the verification loop:
   - It fetches byte `buf[i]`.
   - It computes `buf[i] ^ 0x5A`.
   - It compares the result with `enc_table[i]`, where `enc_table` is a static byte array residing in the `.rodata` section at address `0x2020`.
   - If any byte does not match, the function prints "Access Denied" and exits.
6. If all 35 bytes match, it prints "Access Granted" and exits.

## Extracting the Target Ciphertext

We dump the contents of `.rodata` around `0x2020`:

```bash
objdump -s -j .rodata keypad
```

Extracting the 35 bytes from offset `0x2020`:

```text
29 33 39 2e 3c 21 22 6a 28 05 3d 6e 2e 69 05 29
6b 34 3d 36 69 05 38 23 2e 69 05 31 69 23 05 28
69 2c 27
```

## Reversing the Transformation

Because XOR is its own inverse, the expected character at index $i$ is simply:
`input[i] = enc_table[i] ^ 0x5A`

We implement the solver in Python:

```python
enc_hex = "2933392e3c21226a28053d6e2e6905296b343d36690538232e69053169230528692c27"
enc = bytes.fromhex(enc_hex)
key = 0x5A

flag = bytes(b ^ key for b in enc)
print(flag.decode())
```

Running the solver outputs the decoded flag string.

Solve: `solve/solve.py`

Flag: `sictf{x0r_g4t3_s1ngl3_byt3_k3y_r3v}`
