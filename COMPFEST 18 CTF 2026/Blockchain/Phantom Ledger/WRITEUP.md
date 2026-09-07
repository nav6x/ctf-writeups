# Phantom Ledger (COMPFEST 18, blockchain)

The flag name is bait, and I fell for it for a while. It literally spells out "cross-function reentrancy with ECDSA malleability," so I sat on `relayWithdraw` trying to forge a signature, when the actual solve is much simpler.

The signature angle is a dead end for concrete reasons worth spelling out. The only account holding the 10 ETH is `balances[setup]`, and `setup` is a contract, so it has no private key and can't sign anything that recovers to a funded signer. ECDSA malleability only hands you a second valid signature for one you already have, useless when you can't produce the first. Poking at `ecrecover` returning `address(0)` goes nowhere because `require(signer != address(0))` kills it, and `proposeRelayer` / `setFeeRate` are `onlyOwner`, which I'm not. So the entire cryptographic side is closed.

The real bug is in `transferCredit`, and it's mundane. Its access check is `msg.sender == from || msg.sender == relayer`, and the setup contract handed `_player` the relayer role in its constructor, so I've been the relayer the whole time. That means `transferCredit(setup, me, 10 ether)` moves the credit to me directly, and then `withdraw(10 ether)` drops the vault to zero. `isSolved()` only checks that the balance is zero, so all the reentrancy and malleability framing in the flag name is pure misdirection; the intended-looking path never needed to exist.

One note on the proof-of-work gate in front of the instance. I nearly piped `pwn.red/pow` straight into a shell, but pulled the script first and saw it fetches a binary from GitHub, which I didn't want to run blind. Instead I reimplemented the redpwn sloth VDF (repeated squaring modulo `2^1279 - 1`, difficulty 10000) in Python, about 85 seconds, and self-verified the answer against the check math before sending it, since I didn't want to burn the ticket on a bad solution.

Flag: `COMPFEST18{ph4nt0m_l3dg3r_cr0ss_funct10n_r33ntr4ncy_w1th_ecdsa_m4ll3ab1l1ty}`
