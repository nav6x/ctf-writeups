enc = bytes.fromhex("2933392e3c21226a28053d6e2e6905296b343d36690538232e69053169230528692c27")
print(bytes(b ^ 0x5a for b in enc).decode())
