# Quantum Executor (TraceBash CTF, rev)

A self-modifying bytecode VM, where the flag check runs under two different instruction sets: one before a special opcode rewrites the machine, and one after.

You get three files: `executor`, `loader.bin`, and `vm.bin`. The `executor` runs `loader.bin` as a tiny VM interpreter that in turn executes `vm.bin` as bytecode. So `loader.bin` is the CPU and `vm.bin` is the program.

`loader.bin` implements 14 opcodes: add, sub, xor, mov, load, store, the jumps, equality, read, halt, and one odd one, opcode `0xd`. Opcode `0xd` is the self-rewrite. When executed it flips the entire opcode table so every opcode number now maps to the reversed handler, and it XORs the rest of the bytecode with `0x5a`. In other words, the same byte means one instruction before `0xd` and a different instruction after it, and the code that runs after `0xd` is only meaningful once it's been de-XORed.

The check is split across that boundary. The first half of `vm.bin`, running under the original instruction set, verifies the `TBCTF{` prefix and loads 16 input bytes, then does a series of per-byte XOR/add/sub checks that pin down the first chunk, `mUt4t1ng_vm_ch4n`. Then opcode `0xd` fires. The second half decrypts and runs under the new opcode map, checking 16 more bytes, `g3s_its_0pc0d3s`, and a final `}`.

Rather than reverse the constraints by hand, I wrote a Python emulator that faithfully copies the self-modify step, including the table flip and the `0x5a` XOR, fed it the reconstructed input, and it returned success.

Flag: `TBCTF{mUt4t1ng_vm_ch4ng3s_its_0pc0d3s!}`
