# FrontRunner_MU (Security Impossible CTF 2026 - Monash University, blockchain)

FrontRunner is a smart contract challenge simulating an on-chain bounty hunt. The target contract holds a reward payout unlocked by submitting a secret preimage string to the `claim(string)` function. A competing automated bot periodically checks the contract and attempts to claim the prize.

## Understanding Mempool Visibility and Front-Running

In public blockchain networks such as Ethereum, transactions submitted to an RPC node enter the public transaction pool (mempool) before miners or validators select and bundle them into blocks. Because transactions in the mempool are unencrypted, anyone running a node can inspect pending transactions, analyze their calldata, and see what function is being executed and with what parameters.

If a contract relies on secret information submitted in plain calldata without a commit-reveal scheme, an adversary can extract that secret from the pending transaction, craft an identical transaction, and attach a higher gas price (`priorityFeePerGas`). Validators order transactions by gas price to maximize revenue, ensuring the attacker's transaction is mined first.

## Analyzing the Contract

We inspect the contract functions by decompiling the deployed bytecode:
- `broadcastAnswer()`: A public view function that returns a string. Calling it returns `"peel-away-393bbff3"`.
- `claim(string answer)`: Checks whether `sha256(bytes(answer))` matches the stored target hash, marks the bounty as claimed, and assigns the winner.

Watching the mempool with `cast` also reveals that the victim bot continually broadcasts transactions trying to call `claim("peel-away-393bbff3")` at standard network gas rates (2 gwei).

## Executing the Front-Run

Because the answer is exposed both in the mempool and directly through `broadcastAnswer()`, we query the string and fire our own `claim()` transaction with a significantly higher gas price (100 gwei):

```bash
ANSWER=$(cast call $CONTRACT "broadcastAnswer()(string)" --rpc-url $RPC)
cast send $CONTRACT "claim(string)" "$ANSWER" --gas-price 100gwei --rpc-url $RPC --private-key $PK
```

The Anvil node orders our 100 gwei transaction at the very beginning of the block. When the transaction settles, the contract records our address as the winner. Calling the challenge `/flag` endpoint confirms the solve and awards the flag.

Solve: `solve/solve.sh`

Flag: `sictf{57bda9440f4260da4359057008846929}`
