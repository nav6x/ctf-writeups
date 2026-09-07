# BlockJail (COMPFEST 18, blockchain)

The goal is to satisfy an `isSolved` that demands three things at once: a path opened, a target balance drained to zero, and the "palace" solved. The interesting constraints are all about what contract BlockJail will even listen to.

Getting connected came first. The launcher is behind a redpwn-style proof of work, and my first attempt kept failing verification because the order was custom: you raise `x` to `2^1277` and then XOR before squaring, not the usual square-then-XOR. Once I flipped that it went through.

The `PalaceVault` source was never shipped, so I pulled its bytecode straight off chain. pyevmasm labeled every `0x5f` and `0xfe` as INVALID, which had me lost for a bit, so I wrote a tiny disassembler that actually understands `PUSH0`. That let me read what the vault expected.

The core mechanic is that BlockJail only listens to a single agent contract, set via `enter()`, and `enter()` runs `_validateAgentRuntime` over your bytecode. The rules are strict: at most 36 bytes, only ten whitelisted opcodes, no jumps and no math, exactly one `delegatecall`, and a pushed address below `2^144` that already holds code. In other words it wants a mined vanity proxy.

Two misreads cost me time. First I had a comparison in `beginInfiltration` backwards, thinking the card bytes had to be `>= 3`, which made the drain index unreachable and the whole thing look dead. It's actually `<= 3`, which opens up the card `0001030001` that walks set-solved, clear-guard, drain, jump-end. Second, the remote node rejects any real-sized deploy to a sub-`2^144` address. I thought that was an EVM rule until I reproduced it on local anvil, where the deploy worked fine, so it's the remote being restrictive rather than a protocol constraint.

The fix for that is indirection: instead of putting the logic at the vanity address, I made the agent a 45-byte EIP-1167 minimal-proxy at the mined vanity address that `delegatecall`s the real, fat logic contract `L` living at a normal address. The tiny proxy passes `_validateAgentRuntime`, and the big contract lives elsewhere. Then a single transaction runs `enter`, `openPath`, `infiltrate`, `stealHeart`; `enter` sets `beneficiary = tx.origin` so `stealHeart` drains back to me, both balances hit zero, and `isSolved` returns true.

Solve: `solve/blockjail_solve.py`, `solve/exploit.py`

Flag: `COMPFEST18{I_guess_bro_here_is_relatively_secure_mirror_flag_you_have_searched_for_0f95fd47}`
