load("attack.sage")   # brings in recover_d, hnum, etc.
import json
data=json.load(open("data.json"))
hs=[hnum(m) for m in data["m"]]
rs=[Integer(x) for x in data["r"]]
ss=[Integer(x) for x in data["s"]]
d=recover_d(rs,ss,hs)
out=open("flag_out.txt","w")
out.write("d = %s\n" % d)
if d is not None:
    from Crypto.Cipher import AES
    key=int(d).to_bytes(32,"big")
    ctv=int(data["ct"])
    ctb=ctv.to_bytes((ctv.bit_length()+7)//8,"big")
    if len(ctb)%16: ctb=b"\x00"*(16-len(ctb)%16)+ctb
    pt=AES.new(key,AES.MODE_ECB).decrypt(ctb)
    out.write("flag = %r\n" % pt)
out.close()
