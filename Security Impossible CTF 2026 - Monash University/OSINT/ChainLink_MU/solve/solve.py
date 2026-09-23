raw = bytes.fromhex("422a0c1d0839075e07285507300701471c0f451a1a162d326a376927")
key = b"1CoinBankDepositClusterZZZZZZZZZZZZZ"
print(bytes(c ^ key[i % len(key)] for i, c in enumerate(raw)).decode())
