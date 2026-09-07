import json
from hashlib import sha256
n=0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
KNOWN={8:0x2d,13:0x2d,18:0x2d,23:0x2d,14:0x34}
UNK=[i for i in range(32) if i not in KNOWN]
CENTER=75;BOUND=27
w=[ZZ(256)^(31-pos) for pos in UNK]
A=sum(ZZ(256)^(31-pos)*val for pos,val in KNOWN.items())+sum(ZZ(256)^(31-pos)*CENTER for pos in UNK)
def hnum(m): return Integer(int.from_bytes(sha256(m.encode()).digest(),"big"))
data=json.load(open("data.json"))
hs=[hnum(m) for m in data["m"]]; rs=[Integer(x) for x in data["r"]]; ss=[Integer(x) for x in data["s"]]
Zn=Integers(n); Ns=len(rs); L=len(UNK)
B=[Zn(ss[i])*A-Zn(hs[i]) for i in range(Ns)]; ri=[Zn(rs[i])^-1 for i in range(Ns)]
R=Ns-1; TOT=L*Ns
def idx(sg,q): return sg*L+q
coeffs=[[0]*TOT for _ in range(R)]; consts=[0]*R
for r in range(R):
    i=r+1
    for q in range(L):
        coeffs[r][idx(i,q)]=int(ri[i]*Zn(ss[i])*w[q])
        coeffs[r][idx(0,q)]=int((-ri[0]*Zn(ss[0])*w[q])%n)
    consts[r]=int((ri[i]*B[i]-ri[0]*B[0])%n)
K=ZZ(2)^400
dim=TOT+R+1
M=Matrix(ZZ,dim,dim)
for l in range(TOT):
    M[l,l]=1
    for r in range(R): M[l,TOT+r]=coeffs[r][l]*K
for r in range(R): M[TOT+r,TOT+r]=n*K
for r in range(R): M[dim-1,TOT+r]=consts[r]*K
M[dim-1,dim-1]=BOUND
Bred=M.LLL()
res=open("fast_out.txt","w")
found=False
for row in Bred:
    if any(row[TOT+r]!=0 for r in range(R)): continue
    h=row[dim-1]
    if h in (BOUND,-BOUND):
        sign=1 if h==BOUND else -1
        deltas=[sign*row[l] for l in range(TOT)]
        if all(abs(x)<=BOUND for x in deltas):
            k0=A+sum(w[q]*deltas[idx(0,q)] for q in range(L))
            d=Integer(Zn(rs[0])^-1*(Zn(ss[0])*Zn(k0)-Zn(hs[0])))
            ok=(Zn(ss[1])*(A+sum(w[q]*deltas[idx(1,q)] for q in range(L)))-Zn(hs[1])-Zn(rs[1])*d)==0
            if ok:
                res.write("d = %s\n"%d)
                from Crypto.Cipher import AES
                key=int(d).to_bytes(32,"big"); ctv=int(data["ct"])
                ctb=ctv.to_bytes((ctv.bit_length()+7)//8,"big")
                if len(ctb)%16: ctb=b"\x00"*(16-len(ctb)%16)+ctb
                res.write("flag = %r\n"%AES.new(key,AES.MODE_ECB).decrypt(ctb))
                found=True; break
res.write("found=%s\n"%found); res.close()
