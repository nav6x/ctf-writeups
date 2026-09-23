# ChainLink_MU (Security Impossible CTF 2026 - Monash University, osint)

The challenge drops us into an open-source cryptocurrency forensics investigation. We are given `transactions.json`, an export of Bitcoin transaction records; `labels.json`, a dataset mapping known address clusters to corporate entities; and `BRIEF.txt`, an investigative warrant briefing. The objective is to trace ransom proceeds originating from a known extortion address, identify the deposit exchange, and decrypt the transaction memo holding the flag.

## UTXO Mechanics and Peel Chains

In Bitcoin and UTXO-based blockchains, a transaction consumes one or more unspent transaction outputs (inputs) and creates new outputs. When a user sends a payment, the full value of the input UTXO must be consumed. The difference between the input sum and the desired payment amount is sent to a newly generated change address owned by the sender.

Ransomware groups and money launderers often use a technique known as a **peel chain** to move large illicit balances:
- The initial address holds a large lump sum.
- A transaction sends a small portion of the funds to a destination (e.g. an accomplice or test address) while "peeling" the vast majority of the remaining balance to a fresh change address under the attacker's control.
- This process repeats consecutively across multiple hops until the final remaining balance is deposited into an exchange or mixer.

## Tracing the Peel Chain

Starting from the ransomware collection address `1RanS0mCollect0r...`:
1. We inspect the transaction that spends the funds from `1RanS0mCollect0r...`.
2. Out of the transaction outputs, one is small (the peel) and one holds the majority balance.
3. We select the largest output address and query `transactions.json` for the next transaction spending that output.
4. We repeat this hop selection across 7 consecutive transactions.

At hop 7, the high-value transaction output terminates at address:

```text
1CoinBankDepositClusterZZZZZZZZZZZZZ
```

Cross-referencing `labels.json` confirms that this address belongs to a known custodial exchange deposit cluster:

```json
{
  "1CoinBankDepositClusterZZZZZZZZZZZZZ": {
    "entity": "CoinBank Global",
    "category": "Exchange",
    "cluster_id": 94821
  }
}
```

## Decrypting the OP_RETURN Memo

Examining the final deposit transaction reveals an `OP_RETURN` script output holding a hexadecimal payload:

```text
422a0c1d0839075e07285507300701471c0f451a1a162d326a376927
```

`BRIEF.txt` notes that internal communication memos in this syndicate are encrypted using a repeated-key XOR against the target destination address.

Applying the deposit cluster address `1CoinBankDepositClusterZZZZZZZZZZZZZ` as the key:

```python
raw = bytes.fromhex("422a0c1d0839075e07285507300701471c0f451a1a162d326a376927")
key = b"1CoinBankDepositClusterZZZZZZZZZZZZZ"

flag = bytes(c ^ key[i % len(key)] for i, c in enumerate(raw))
print(flag.decode())
```

Decoding the byte stream recovers the flag.

Solve: `solve/solve.py`

Flag: `sictf{f0ll0w_th3_c0ins_h0m3}`
