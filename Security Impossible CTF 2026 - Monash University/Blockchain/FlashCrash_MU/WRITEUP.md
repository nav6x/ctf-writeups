# FlashCrash_MU (Security Impossible CTF 2026 - Monash University, blockchain)

FlashCrash presents a decentralized finance ecosystem running on an Anvil EVM node. The environment includes three contracts: a lending pool, an automated market maker (AMM) exchange, and a flash loan provider. The lending pool holds 5 ETH in liquidity, and the challenge is marked solved whenever the pool balance drops below 0.5 ETH.

## Decompilation and Selector Recovery

The challenge launcher does not supply Solidity source files, so we interact with the RPC endpoint using Foundry's `cast` and decompile the bytecode.

Extracting the 4-byte `PUSH4` function selectors and matching them against Ethereum signature databases reveals the architecture:
- `Market`: `price()`, `buy()`, `sell()`, `ethReserve()`, `tokenReserve()`
- `FlashLender`: `flashLoan(address receiver, uint256 amount)`
- `Pool`: `borrow(uint256 collateral)`

At first glance, the setup suggests an economic oracle attack: borrow a massive sum of tokens via `flashLoan()`, dump them into the AMM `Market` to artificially crash or spike the spot price returned by `price()`, and exploit the distorted valuation inside `borrow()`.

## Discovering the Logic Flaw

Before building a complex multi-contract flash loan arbitrage bot, we decompile the lending pool's `borrow(uint256 collateral)` function (selector `0xe4997dc5`):

```solidity
function borrow(uint256 collateral) external {
    uint256 currentPrice = market.price();
    uint256 payout = (collateral * currentPrice) / 1e18;
    if (payout > address(this).balance) {
        payout = address(this).balance;
    }
    (bool success, ) = msg.sender.call{value: payout}("");
    require(success, "Transfer failed");
}
```

Examining the EVM opcodes confirms a glaring vulnerability: the contract calculates the borrow amount based on the `collateral` argument passed by the caller, but it **never actually transfers collateral from the caller**. There is no `transferFrom()` call, no balance check, and no internal collateral accounting.

The function simply trusts the parameter and transfers that amount of ETH straight to `msg.sender`, capped only by the contract's available balance.

## The One-Line Exploit

Because the function takes no collateral, we bypass the entire flash-loan and AMM price manipulation mechanism. We simply send a single transaction calling `borrow()` with a gigantic collateral value:

```bash
cast send $POOL "borrow(uint256)" 100000000000000000000000 --rpc-url $RPC --private-key $PK
```

The contract evaluates `payout`, caps it at the contract balance (5 ETH), and transfers the entire 5 ETH to our account. The pool balance falls to zero, satisfying `balance < 0.5 ether`. Requesting `/flag` yields the flag immediately.

Solve: `solve/solve.sh`

Flag: `sictf{d16c3f227081a2fe7f776bd4e4c8b40f}`
