import socket
import struct
import sys

def solve(host, port):
    s = socket.socket()
    s.connect((host, port))
    s.recv(64)
    def sendframe(op, p=b""):
        s.sendall(struct.pack(">I", len(p) + 1) + bytes([op]) + p)
    def recvall(n):
        b = b""
        while len(b) < n:
            chunk = s.recv(n - len(b))
            if not chunk:
                break
            b += chunk
        return b
    def recvframe():
        raw_len = recvall(4)
        if not raw_len:
            return None, b""
        N = struct.unpack(">I", raw_len)[0]
        d = recvall(N)
        return d[0], d[1:]
    sendframe(1, b"WG01")
    op, token = recvframe()
    t = bytes((token[i] ^ ((0x5A + 0x11 * i) & 0xFF)) & 0xFF for i in range(len(token)))
    sendframe(2, t)
    recvframe()
    sendframe(3, b"")
    _, flag = recvframe()
    print(flag.decode(errors="replace"))
    s.close()

if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5101
    solve(target, port)
