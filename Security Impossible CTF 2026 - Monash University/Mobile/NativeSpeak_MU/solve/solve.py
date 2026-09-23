blob = bytes.fromhex("6b1802081f0d1001055a34055f1f5a1d5834075a0934135b1934181f195a050c34080358080016")
print(bytes(blob[i + 1] ^ 0x6b for i in range(0x26)).decode())
