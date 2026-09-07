import sys, json
from hashlib import sha256

p  = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
aE = -3
bE = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b
Gx = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296
Gy = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5
n  = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
Fp = GF(p)
E  = EllipticCurve(Fp, [aE, bE])
G  = E(Gx, Gy)

KNOWN = {8:0x2d, 13:0x2d, 18:0x2d, 23:0x2d, 14:0x34}
UNK = [i for i in range(32) if i not in KNOWN]
CENTER = 75
BOUND  = 27

def weights():
    return [ZZ(256)^(31-pos) for pos in UNK]

def const_A():
    A = 0
    for pos,val in KNOWN.items():
        A += ZZ(256)^(31-pos)*val
    for pos in UNK:
        A += ZZ(256)^(31-pos)*CENTER
    return A

def hnum(m):
    return Integer(int.from_bytes(sha256(m.encode()).digest(), "big"))

def recover_d(rs, ss, hs):
    A = const_A()
    w = weights()
    L = len(UNK)
    Ns = len(rs)
    Rn = Fp = None
    Zn = Integers(n)
    B = [ (Zn(ss[i])*A - Zn(hs[i])) for i in range(Ns) ]
    ri = [ Zn(rs[i])^-1 for i in range(Ns) ]
    R = Ns-1
    TOT = L*Ns
    coeffs = [[Zn(0)]*TOT for _ in range(R)]
    consts = [Zn(0)]*R
    def idx(sig,q): return sig*L+q
    for r in range(R):
        i = r+1
        for q in range(L):
            coeffs[r][idx(i,q)] =  ri[i]*Zn(ss[i])*w[q]
            coeffs[r][idx(0,q)] = -ri[0]*Zn(ss[0])*w[q]
        consts[r] = ri[i]*B[i] - ri[0]*B[0]
    dim = TOT + R + 1
    M = Matrix(ZZ, dim, dim)
    for l in range(TOT):
        M[l,l] = 1
        for r in range(R):
            M[l, TOT+r] = ZZ(coeffs[r][l] % n)
    for r in range(R):
        M[TOT+r, TOT+r] = n
    for r in range(R):
        M[dim-1, TOT+r] = ZZ(consts[r] % n)
    M[dim-1, dim-1] = BOUND
    B_red = M.LLL()
    for row in B_red:
        if all(row[TOT+r]==0 for r in range(R)) and abs(row[dim-1])==BOUND:
            sign = 1 if row[dim-1]==BOUND else -1
            deltas = [ sign*row[l] for l in range(TOT) ]
            if all(abs(dv)<=BOUND for dv in deltas):
                k0 = A + sum(w[q]*deltas[idx(0,q)] for q in range(L))
                d = (Zn(rs[0])^-1 * (Zn(ss[0])*Zn(k0) - Zn(hs[0])))
                d = Integer(d)
                ok = (Zn(ss[1])* ( A + sum(w[q]*deltas[idx(1,q)] for q in range(L)) ) - Zn(hs[1]) - Zn(rs[1])*d) == 0
                if ok:
                    return d
    return None

def selftest():
    import uuid, secrets
    d = secrets.randbelow(n-1)+1
    rs=[];ss=[];hs=[]
    for i in range(6):
        m=str(i)
        h=hnum(m)
        while True:
            kstr=str(uuid.uuid4())[:32]
            k=Integer(int.from_bytes(kstr.encode(),"big"))
            if k % n == 0: continue
            P=k*G
            r=Integer(P.xy()[0]) % n
            if r==0: continue
            s=(inverse_mod(k,n)*(h + r*d)) % n
            if s==0: continue
            break
        rs.append(r);ss.append(s);hs.append(h)
    dd=recover_d(rs,ss,hs)
    print("[selftest] recovered:", dd is not None and dd==d)
    return dd==d

if __name__=="__main__":
    if len(sys.argv)>1 and sys.argv[1]=="selftest":
        ok=selftest()
        sys.exit(0 if ok else 1)
    data=json.load(open(sys.argv[1]))
    hs=[hnum(m) for m in data["m"]]
    rs=[Integer(x) for x in data["r"]]
    ss=[Integer(x) for x in data["s"]]
    d=recover_d(rs,ss,hs)
    print("d =", d)
    if d is not None:
        from Crypto.Cipher import AES
        key=int(d).to_bytes(32,"big")
        ctb=int(data["ct"]).to_bytes((int(data["ct"]).bit_length()+7)//8,"big")
        pt=AES.new(key,AES.MODE_ECB).decrypt(ctb)
        print("flag =", pt)
