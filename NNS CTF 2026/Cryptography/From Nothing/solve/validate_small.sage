from sage.all import pari
pari.allocatemem(1<<28)
set_random_seed(7)
n = 11

def make_instance(p):
    F = GF(p); R.<x> = PolynomialRing(F)
    H = HyperellipticCurve(x^n, 1, "u,v")
    J = H.jacobian(); J = J(J.base_ring())
    x0 = next(t for t in iter(F.random_element, 0) if (1+4*t^n).is_square())
    G = J(H.lift_x(x0)); k = randint(2,p); D = k*G
    e = int(D[1][0])
    while True:
        xf = F.random_element()
        try: P = H.lift_x(xf); break
        except Exception: continue
    ct = e*J(P)
    Du = [int(c) for c in D[0].list()]
    return dict(p=int(p),H=H,J=J,Du=Du,ct=ct,e_true=e,xf=int(xf))

def sqrt_mod_u(disc, u):
    from itertools import product
    R = u.parent()
    perfac=[]
    for (g,mult) in u.factor():
        Q = R.quotient(g)
        s = Q(disc).sqrt().lift()
        perfac.append((g,[s % g, (-s) % g]))
    from sage.arith.misc import CRT_list
    gs=[g for g,_ in perfac]; sels=[o for _,o in perfac]
    return [ CRT_list(list(c),gs) % u for c in product(*sels) ]

def recover_e_cands(p, Du):
    F=GF(p); R.<x>=PolynomialRing(F); u=R(Du)
    disc = 1+4*x^n
    inv2=inverse_mod(2,p); cands=set()
    for w in sqrt_mod_u(disc,u):
        v=((R(-1)+w)*inv2)%u; cands.add(int(v[0]))
        v2=((R(-1)-w)*inv2)%u; cands.add(int(v2[0]))
    return u,cands

primes=[p for p in prime_range(50,4000) if p%11==1][:6]
print("test primes:",primes)
for p in primes:
    inst=make_instance(p); H=inst['H']; J=inst['J']; ct=inst['ct']
    u,cands=recover_e_cands(p,inst['Du'])
    chi=H.frobenius_polynomial(); NJ=Integer(chi(1))
    ok_e = inst['e_true'] in cands
    ann = (NJ*ct==J(0))
    recovered=None
    for e in cands:
        Ns=NJ
        while True:
            g=gcd(Ns,e)
            if g==1: break
            Ns//=g
        Prec=inverse_mod(e,Ns)*ct
        up=Prec[0]
        if up.degree()==1 and int((-up[0])) == inst['xf']:
            recovered=e
    print("p=%d #J=%d e_true_in_cands=%s NJ_annihilates=%s flag_recovered=%s (e=%s)"%(p,NJ,ok_e,ann,recovered is not None,recovered))
