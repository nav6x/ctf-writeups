import base64

data = base64.b64decode("HVsCHx7qTQZSRFwC8Fe0HBV17BoMIk01En0e5Tj4piLgZeb9I/GX")
key = b"n1ghtj4r"
print(bytes(((data[i] ^ key[i % 8]) - i) & 0xFF for i in range(len(data))).decode())
