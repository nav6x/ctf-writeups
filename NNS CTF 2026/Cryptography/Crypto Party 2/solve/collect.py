import json, sys
from pwn import remote, context
context.log_level="error"

HOST="crypto-party-2-7ef3e85c6344.chall.nnsc.tf"
PORT=1337

io=remote(HOST,PORT,ssl=True)
line=io.recvline().decode()
ct=int(line.split("ct:")[1].strip())
io.recvline()
ms=[];rs=[];ss=[]
for i in range(6):
    io.recvuntil(b"Enter the name of your friend:")
    m=str(i)
    io.sendline(m.encode())
    io.recvuntil(b"Invitation code = ")
    code=io.recvline().decode().strip()
    r,s=code.split(":")
    ms.append(m);rs.append(r);ss.append(s)
io.close()
json.dump({"ct":str(ct),"m":ms,"r":rs,"s":ss}, open(sys.argv[1] if len(sys.argv)>1 else "data.json","w"))
print("collected ct + 6 sigs")
