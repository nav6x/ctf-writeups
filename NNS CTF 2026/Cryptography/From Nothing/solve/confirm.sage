import itertools
from sage.all import *
path="/mnt/c/Users/user/Downloads/gaslight/NNS CTF/From Nothing/crypto_from-nothing/output.txt"
d={}
for line in open(path):
    line=line.strip()
    if "=" in line:
        k,v=line.split("=",1); d[k.strip()]=v.strip()
p=Integer(d["p"])
Du=[Integer(t) for t in d["D_u"].strip("[] ").split(",")]
uu=[Integer(t) for t in d["u"].strip("[] ").split(",")]
vv=[Integer(t) for t in d["v"].strip("[] ").split(",")]
N=Integer(37068896621564204429502578230432547945804198179896312045738986890099609264808344677710179881448531443092856468025979602800261078003906729051773082597470150853989944861404534380009478756985413136811229024490075796458106425888724496755180995027265388699859064636584690200421064677091843562247992566867628166762353559638164454937486060445580485378205470995984707493044984919294458510947166753224951290424612393914355326879283627287331291193398097321445185915582095418356849954831671407669847346003860735651483759003551374080409110090559290459744324673701032280635914106899659071410518434297043837358235763388410085969948558547318985037848222486058568009054506101512298654800326707885644932077640220123354534260998085027245851456514185440914911523785178548445598402162902016)
print("N bits:", N.nbits(), " p^5 bits:", (p**5).nbits(), flush=True)
Fp=FiniteField(p); R=PolynomialRing(Fp,"x"); x=R.gen()
H=HyperellipticCurve(x**11,1,"u,v"); Jc=H.jacobian(); Jc=Jc(Jc.base_ring())
ct=Jc(R([Fp(c) for c in uu]),R([Fp(c) for c in vv]))
print("N*ct == 0 :", N*ct==Jc(0), flush=True)
uD=R([Fp(c) for c in Du]); persqrt=[]
for f,_ in uD.factor():
    dg=f.degree()
    if dg==1:
        r=-f[0]/f[1]; s0=(1+4*r**11).sqrt(); persqrt.append((f,[R(s0),R(-s0)]))
    else:
        Fq=GF(p**dg,"a",modulus=f); r=Fq.gen(); s0=(1+4*r**11).sqrt()
        persqrt.append((f,[R(s0.polynomial()),R((-s0).polynomial())]))
print("u_D factor degrees:", [f.degree() for f,_ in persqrt], flush=True)
half=Fp(1)/Fp(2); ecands=set()
for combo in itertools.product(*[o for _,o in persqrt]):
    s=crt(list(combo),[f for f,_ in persqrt]) % uD
    v=((s-1)*half)%uD
    ecands.add(Integer(v[0])%p); ecands.add(Integer((-1-v[0]))%p)
print("e candidates:", len(ecands), flush=True)
def l2b(t):
    t=int(t); return t.to_bytes((t.bit_length()+7)//8,"big") if t else b""
for e in sorted(ecands):
    if gcd(e,N)!=1: continue
    Pt=Integer(inverse_mod(e,N))*ct; u0=Pt[0]
    if u0.degree()!=1: continue
    b=l2b(Integer(-u0[0]/u0[1]))
    if b.startswith(b"NNS{"):
        print("CONFIRMED FLAG:", b.decode(), flush=True)
        print("e =", e, flush=True)
        break
