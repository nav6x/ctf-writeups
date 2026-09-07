from sage.all import *
import random

q, t = 2**768, 2**512
n, m, w, b = 16, 112, 130, 16
R = Zmod(q)

def keygen():
    s = random_vector(R, n)
    r = next_prime(2**31)
    p = random_prime(2**520, lbound=2**519)
    sk = random_prime(2**128, lbound=2**127)
    A = random_matrix(ZZ, m, n, x=0, y=b)
    e = vector(ZZ, [randint(0, r-1) for _ in range(m)])
    k = R(p)/R(sk)
    B = A*s.change_ring(ZZ).change_ring(R) + k*e.change_ring(R)
    return (A, B), (s, r, int(p), int(sk), e, int(k))

def encrypt(pk, pt):
    A, B = pk
    I = [randint(0, m-1) for _ in range(w)]
    return sum(A[i] for i in I), pt - sum(B[i] for i in I)

set_random_seed(1)
pk, sec = keygen()
A, B = pk
s_true, r, p, sk, e_true, k = sec
pt_true = 12345678901234567890
u, v = encrypt(pk, R(pt_true))
u = vector(ZZ,[int(x) for x in u]); v = int(v)

print("[sim] r bits", r.bit_length(), "k odd?", k%2)

Bz = vector(ZZ,[int(x) for x in B])
K = A.left_kernel().basis_matrix().LLL()
a = vector(ZZ,[int((K.row(j)*Bz)%q) for j in range(K.nrows())])
L=len(a); F=2**728
M=Matrix(ZZ,L+1,L+1); M[0,0]=1
for j in range(L):
    M[0,j+1]=F*a[j]; M[j+1,j+1]=F*q
Rr=M.LLL()
def center(x):
    x%=q
    return x-q if x>q//2 else x
kk=None
for i in range(Rr.nrows()):
    y=int(Rr[i,0])%q
    if y==0 or y%2==0: continue
    if max(abs(center(a[j]*y)) for j in range(L))<2**80:
        kk=inverse_mod(y,q); break
print("[sim] k match:", kk==k)

Bp = vector(ZZ,[int((inverse_mod(kk,q)*int(B[i]))%q) for i in range(m)])
chk_true = [int((int(Bp[i]) - A.row(i)*s_true.change_ring(ZZ))%q) for i in range(m)]
print("[sim] Bp uses true s: err in [0,r)?", min(chk_true), max(chk_true), r)

Gen = block_matrix(ZZ, [[A.transpose()], [q*identity_matrix(m)]])
Lred = Gen.LLL()
Lred = Lred.matrix_from_rows(range(Lred.nrows()-m, Lred.nrows()))
G,_ = Lred.gram_schmidt()
def babai(basis,G,target):
    bvec=vector(QQ,target)
    for i in reversed(range(basis.nrows())):
        c=(bvec.dot_product(G[i]))/(G[i].dot_product(G[i]))
        bvec=bvec-c.round()*basis.row(i)
    return vector(ZZ,[target[j]-bvec[j] for j in range(len(target))])
tgt=vector(ZZ,[int(Bp[i])-r//2 for i in range(m)])
P=babai(Lred,G,tgt)
e_rec=vector(ZZ,[int(Bp[i])-int(P[i]) for i in range(m)])
print("[sim] Attempt A err range:", min(e_rec),max(e_rec), " matches true e:", e_rec==e_true)

Aq=A.change_ring(Zmod(q)); rows=[]
for i in range(m):
    if Matrix(GF(2),A.matrix_from_rows(rows+[i])).rank()==len(rows)+1:
        rows.append(i)
    if len(rows)==n: break
Asub=Aq.matrix_from_rows(rows)
Pv=vector(Zmod(q),[int(P[rows[t]])%q for t in range(n)])
sp=Asub.solve_right(Pv)
sp=vector(ZZ,[int(x)%q for x in sp])
chk=[int((int(Bp[i]) - A.row(i).dot_product(sp))%q) for i in range(m)]
print("[sim] recovered s' err range:", min(chk),max(chk))
s_full = vector(ZZ,[int((kk*int(sp[i]))%q) for i in range(n)])  # s = k*s'

Wt=2**392
Rk=Matrix(ZZ,[[Wt,kk],[0,q]]).LLL()
sk_r=p_r=None
for row in Rk:
    if row[0]==0: continue
    cs=abs(int(row[0]))//Wt
    if cs==0: continue
    cp=int((kk*cs)%q)
    if 0<cs<2**130 and 2**515<cp<2**521 and is_prime(cs) and is_prime(cp):
        sk_r,p_r=int(cs),cp; break
print("[sim] sk,p recovered:", sk_r==sk, p_r==p, "checkrel:", (kk*sk_r)%q==p_r)

ww=(v + int(u.dot_product(s_full)))%q
X0=(sk_r*ww)%q
found=None
for X in (X0, X0-q):
    Mrem=X%p_r
    for cand in ([Mrem//sk_r] if Mrem%sk_r==0 else []) + [int((Mrem*inverse_mod(sk_r,p_r))%p_r)]:
        if cand==pt_true: found=cand
print("[sim] DECRYPT pt==pt_true:", found==pt_true, "(pt_true was", pt_true, ")")
