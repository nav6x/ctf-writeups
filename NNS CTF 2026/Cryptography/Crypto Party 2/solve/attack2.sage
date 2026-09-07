import sys, json
from hashlib import sha256

p  = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
aE = -3
bE = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b
Gx = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296
Gy = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5
n  = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
Fp = GF(p); E=EllipticCurve(Fp,[aE,bE]); G=E(Gx,Gy)

KNOWN={8:0x2d,13:0x2d,18:0x2d,23:0x2d,14:0x34}
UNK=[i for i in range(32) if i not in KNOWN]
CENTER=75; BOUND=27
def weights(): return [ZZ(256)^(31-pos) for pos in UNK]
def const_A():
    A=0
    for pos,val in KNOWN.items(): A+=ZZ(256)^(31-pos)*val
    for pos in UNK: A+=ZZ(256)^(31-pos)*CENTER
    return A
def hnum(m): return Integer(int.from_bytes(sha256(m.encode()).digest(),"big"))

def verify_d(d, rs, ss, hs, A, w, L):
    Zn=Integers(n)
    for i in range(len(rs)):
        ki = (Zn(ss[i])^-1 * (hnum_or(hs[i]) + Zn(rs[i])*d)) if False else None
    return None

def recover_d(rs,ss,hs):
    Zn=Integers(n)
    A=const_A(); w=weights(); L=len(UNK); Ns=len(rs)
    B=[Zn(ss[i])*A-Zn(hs[i]) for i in range(Ns)]
    ri=[Zn(rs[i])^-1 for i in range(Ns)]
    R=Ns-1; TOT=L*Ns
    def idx(sg,q): return sg*L+q
    coeffs=[[0]*TOT for _ in range(R)]; consts=[0]*R
    for r in range(R):
        i=r+1
        for q in range(L):
            coeffs[r][idx(i,q)]=int(ri[i]*Zn(ss[i])*w[q])
            coeffs[r][idx(0,q)]=int(-ri[0]*Zn(ss[0])*w[q]%n)
        consts[r]=int(ri[i]*B[i]-ri[0]*B[0])%n
    K=ZZ(2)^400
    dim=TOT+R+1
    M=Matrix(ZZ,dim,dim)
    for l in range(TOT):
        M[l,l]=1
        for r in range(R): M[l,TOT+r]=coeffs[r][l]*K
    for r in range(R): M[TOT+r,TOT+r]=n*K
    for r in range(R): M[dim-1,TOT+r]=consts[r]*K
    M[dim-1,dim-1]=BOUND
    Bred=M.BKZ(block_size=30)
    def try_deltas(deltas):
        k0=A+sum(w[q]*deltas[idx(0,q)] for q in range(L))
        d=Integer(Zn(rs[0])^-1*(Zn(ss[0])*Zn(k0)-Zn(hs[0])))
        ok=(Zn(ss[1])*(A+sum(w[q]*deltas[idx(1,q)] for q in range(L)))-Zn(hs[1])-Zn(rs[1])*d)==0
        return d if ok else None
    for row in Bred:
        if any(row[TOT+r]!=0 for r in range(R)): continue
        h=row[dim-1]
        if h in (BOUND,-BOUND):
            sign=1 if h==BOUND else -1
            deltas=[sign*row[l] for l in range(TOT)]
            if all(abs(x)<=BOUND for x in deltas):
                d=try_deltas(deltas)
                if d is not None: return d
    return None

def selftest(trials=5):
    import uuid, secrets
    good=0
    for _ in range(trials):
        d=secrets.randbelow(n-1)+1
        rs=[];ss=[];hs=[]
        for i in range(6):
            m=str(i); h=hnum(m)
            while True:
                k=Integer(int.from_bytes(str(uuid.uuid4())[:32].encode(),"big"))
                if k%n==0: continue
                P=k*G; r=Integer(P.xy()[0])%n
                if r==0: continue
                s=(inverse_mod(k,n)*(h+r*d))%n
                if s==0: continue
                break
            rs.append(r);ss.append(s);hs.append(h)
        dd=recover_d(rs,ss,hs)
        good += 1 if dd==d else 0
    return good,trials
