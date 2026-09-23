# WireGame_MU (Security Impossible CTF 2026 - Monash University, misc)

The challenge provides a compiled Linux client binary `wireclient` (64-bit unstripped ELF) alongside a remote server running on a custom TCP port. The program implements a bespoke network protocol to authenticate and retrieve flags. We need to reverse-engineer the packet framing and handshake state machine to write an independent solver.

## Static Analysis of wireclient

Opening `wireclient` in Ghidra or disassembling it with `objdump` reveals a clean binary with intact symbol names: `main`, `sendframe`, `recvframe`, and `transform_token`.

Disassembling `sendframe` and `recvframe`:

```c
void sendframe(int fd, uint8_t opcode, const uint8_t *payload, uint32_t len) {
    uint32_t netlen = htonl(len + 1);
    write(fd, &netlen, 4);
    write(fd, &opcode, 1);
    if (len > 0) {
        write(fd, payload, len);
    }
}
```

This establishes the binary framing format:
- 4 bytes: Total length encoded as a big-endian 32-bit unsigned integer. Critically, this length counts the 1-byte opcode in addition to the payload bytes.
- 1 byte: Command opcode.
- $N$ bytes: Frame payload data.

`recvframe` operates inversely: it reads a 4-byte length $L$, allocates a buffer of size $L$, and reads $L$ bytes containing the 1-byte response opcode followed by $L-1$ payload bytes. The server sets the high bit on response opcodes (request `0x01` receives response `0x81`).

## The Handshake State Machine

Tracing `main` outlines the protocol sequence:
1. **Banner**: Upon establishing the TCP connection, the server sends a raw text greeting: `WGP ready\n`. The client reads this string before transmitting frames.
2. **HELLO (Opcode 0x01)**: The client sends opcode `0x01` with the 4-byte ASCII payload `"WG01"`. The server responds with opcode `0x81` carrying a 16-byte session token.
3. **Token Transformation**: The client passes the received session token through an arithmetic transformation:
   For each byte at index $i$:
   `transformed[i] = token[i] ^ ((0x5A + 0x11 * i) & 0xFF)`
   The keystream starts at base value `0x5A` and increments by `0x11` per byte index.
4. **AUTH (Opcode 0x02)**: The client sends opcode `0x02` with the transformed token. The server verifies the token and responds with opcode `0x82` containing `"OK"`.
5. **GETFLAG (Opcode 0x03)**: The client sends opcode `0x03` with an empty payload. The server replies with opcode `0x83` containing the flag string.

## Implementing the Solver

We implement the complete state machine in Python without relying on external libraries:

```python
import socket
import struct

HOST = "target-misc-05-wiregame"
PORT = 5101

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((HOST, PORT))
banner = s.recv(64)

def sendframe(op, payload=b""):
    length = len(payload) + 1
    s.sendall(struct.pack(">I", length) + bytes([op]) + payload)

def recvall(n):
    data = b""
    while len(data) < n:
        chunk = s.recv(n - len(data))
        if not chunk:
            raise EOFError("Socket closed")
        data += chunk
    return data

def recvframe():
    length = struct.unpack(">I", recvall(4))[0]
    data = recvall(length)
    return data[0], data[1:]

sendframe(1, b"WG01")
op, token = recvframe()

transformed = bytes((token[i] ^ ((0x5a + 0x11 * i) & 0xff)) & 0xff for i in range(len(token)))

sendframe(2, transformed)
op, auth_resp = recvframe()

sendframe(3, b"")
op, flag = recvframe()

print(flag.decode().strip())
s.close()
```

Executing the solver returns the flag.

Solve: `solve/solve.py`

Flag: `sictf{fd52544f17c907b02c2644a7ffb39f88}`
