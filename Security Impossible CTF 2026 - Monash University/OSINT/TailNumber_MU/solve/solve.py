import base64

raw = base64.b64decode("KjowLT8oZz0qDDEGN2AlaisMNWkrNGAtKi4=")
key = b"YSSY"
print(bytes(c ^ key[i % 4] for i, c in enumerate(raw)).decode())
