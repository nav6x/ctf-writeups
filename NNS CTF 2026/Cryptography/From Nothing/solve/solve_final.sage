import time, itertools
from sage.all import *
path="/mnt/c/Users/user/Downloads/gaslight/NNS CTF/From Nothing/crypto_from-nothing/output.txt"
d={}
for line in open(path):
    line=line.strip()
    if "=" in line: k,v=line.split("=",1); d[k.strip()]=v.strip()
p=Integer(d["p"])
Du=[Integer(x) for x in d["D_u"].strip("[] ").split(",")]
uu=[Integer(x) for x in d["u"].strip("[] ").split(",")]
vv=[Integer(x) for x in d["v"].strip("[] ").split(",")]
m=22; K=CyclotomicField(m); z=K.gen()
def frac(x): return x-floor(x)
G=K.galois_group(); units=[c for c in range(1,m) if gcd(c,m)==1]
autmap={c:[au for au in G if au(z)==z**c][0] for c in units}
P=K.primes_above(p)[0]; I=K.ideal(1)
for c in units:
    cinv=inverse_mod(c,m); ec=Integer(round(frac(-2*cinv/m)+frac(-11*cinv/m)-frac(-13*cinv/m)))
    if ec: I*=autmap[c](P)**ec
g0=I.gens_reduced()[0]
cand_N=sorted({Integer(prod((1-autmap[c](z**k*g0)) for c in units)) for k in range(m)})
print("candidate orders:",len(cand_N),flush=True)
Fp=FiniteField(p); R=PolynomialRing(Fp,"x"); x=R.gen()
H=HyperellipticCurve(x**11,1,"u,v"); Jc=H.jacobian(); Jc=Jc(Jc.base_ring())
ct=Jc(R([Fp(c) for c in uu]),R([Fp(c) for c in vv]))
zero=Jc(0)
Ntrue=None
for i,N in enumerate(cand_N):
    if Integer(N)*ct==zero:
        Ntrue=N; print("FOUND N (idx %d): %s"%(i,N),flush=True); break
    else:
        print("  idx %d not annihilator"%i,flush=True)
if Ntrue is None:
    print("no annihilator found",flush=True); exit()
uD=R([Fp(c) for c in Du]); persqrt=[]
for f,_ in uD.factor():
    dg=f.degree()
    if dg==1:
        r=-f[0]/f[1]; s0=(1+4*r**11).sqrt(); persqrt.append((f,[R(s0),R(-s0)]))
    else:
        Fq=GF(p**dg,"a",modulus=f); r=Fq.gen(); s0=(1+4*r**11).sqrt()
        persqrt.append((f,[R(s0.polynomial()),R((-s0).polynomial())]))
half=Fp(1)/Fp(2); ecands=set()
for combo in itertools.product(*[o for _,o in persqrt]):
    s=crt(list(combo),[f for f,_ in persqrt]) % uD
    v=((s-1)*half)%uD
    ecands.add(Integer(v[0])%p); ecands.add(Integer((-1-v[0]))%p)
def l2b(n):
    n=int(n); return n.to_bytes((n.bit_length()+7)//8,"big") if n else b""
print("testing %d e-candidates"%len(ecands),flush=True)
for e in ecands:
    if gcd(e,Ntrue)!=1: continue
    Pt=Integer(inverse_mod(e,Ntrue))*ct; u0=Pt[0]
    if u0.degree()!=1: 
        print("  e ok but deg",u0.degree(),flush=True); continue
    fx=Integer(-u0[0]/u0[1]); b=l2b(fx)
    print("  decode:",b[:60],flush=True)
    if b.startswith(b"NNS{") or b.startswith(b"NSS{"):
        print("FLAG:",b,flush=True); break
