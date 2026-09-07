from sage.all import *
import sys
def long_to_bytes(x):
    x=int(x)
    return x.to_bytes((x.bit_length()+7)//8,'big') if x else b'\x00'
def pr(*a): print(*a); sys.stdout.flush()

BASE="/mnt/c/Users/user/Downloads/gaslight/NNS CTF/Light-Weight Encryption/crypto_light-weight-encryption"
ns={}; exec(open(BASE+"/output.py").read(),ns)
Alist,Bvec=ns['pk']; u_list,v=ns['ct']
q=2**768; n,m,w,b=16,112,130,16
A=Matrix(ZZ,m,n,[int(x) for x in Alist])
Bz=vector(ZZ,[int(x) for x in Bvec])
u=vector(ZZ,[int(x) for x in u_list]); v=int(v)
def center(x):
    x%=q; return x-q if x>q//2 else x

K=A.left_kernel().basis_matrix().LLL()
a=vector(ZZ,[int((K.row(j)*Bz)%q) for j in range(K.nrows())])
L=len(a); F=2**728
M=Matrix(ZZ,L+1,L+1); M[0,0]=1
for j in range(L): M[0,j+1]=F*a[j]; M[j+1,j+1]=F*q
Rr=M.LLL()
cand_y=set()
for i in range(Rr.nrows()):
    y=int(Rr[i,0])%q
    if y==0 or y%2==0: continue
    if max(abs(center(a[j]*y)) for j in range(L))<2**100:
        for f in (1,3,5,7,9,11,13,15):
            yy=(y*f)%q
            if yy%2==1: cand_y.add(yy)
            yi=inverse_mod(f,q)*y%q
            if yi%2==1: cand_y.add(yi)
pr("[+] stage1: %d candidate multipliers"%len(cand_y))

Wt=2**392
k=sk=p=None
for y in cand_y:
    kk=inverse_mod(y,q)
    Rk=Matrix(ZZ,[[Wt,kk],[0,q]]).LLL()
    for row in Rk:
        r0=int(row[0]); r1=int(row[1])
        if r0==0 or r0%Wt!=0: continue
        cs=abs(r0//Wt); cp=abs(r1)
        if 2**126<cs<2**130 and 2**515<cp<2**521 and is_prime(cs) and is_prime(cp):
            k,sk,p=kk,int(cs),int(cp); break
    if k is not None: break
assert k is not None, "no k gave valid sk,p"
pr("[+] stage3: sk(%db) p(%db) prime, k*sk==p:%s"%(sk.bit_length(),p.bit_length(),(k*sk)%q==p))

kinv=inverse_mod(k,q)
Bp=vector(ZZ,[int((kinv*int(Bz[i]))%q) for i in range(m)])
Gen=block_matrix(ZZ,[[A.transpose()],[q*identity_matrix(m)]])
Lred=Gen.LLL(); Lred=Lred.matrix_from_rows(range(Lred.nrows()-m,Lred.nrows()))
G,_=Lred.gram_schmidt()
def babai(basis,G,t):
    bv=vector(QQ,t)
    for i in reversed(range(basis.nrows())):
        c=(bv.dot_product(G[i]))/(G[i].dot_product(G[i]))
        bv=bv-c.round()*basis.row(i)
    return vector(ZZ,[t[j]-bv[j] for j in range(len(t))])
P=babai(Lred,G,vector(ZZ,[int(Bp[i])-2**31 for i in range(m)]))
pr("[*] stage2 err range:",min(center(int(Bp[i])-int(P[i])) for i in range(m)),
                           max(center(int(Bp[i])-int(P[i])) for i in range(m)))
Aq=A.change_ring(Zmod(q)); rows=[]
for i in range(m):
    if Matrix(GF(2),A.matrix_from_rows(rows+[i])).rank()==len(rows)+1: rows.append(i)
    if len(rows)==n: break
sp=Aq.matrix_from_rows(rows).solve_right(vector(Zmod(q),[int(P[rows[t]])%q for t in range(n)]))
sp=vector(ZZ,[int(x)%q for x in sp])
s_full=vector(ZZ,[int((k*int(sp[i]))%q) for i in range(n)])
pr("[+] stage2: s recovered")

ww=(v+int(u.dot_product(s_full)))%q
X0=(sk*ww)%q
for X in (X0,X0-q):
    Mrem=X%p
    for cand in (([Mrem//sk] if Mrem%sk==0 else [])+[int((Mrem*inverse_mod(sk,p))%p)]):
        fb=long_to_bytes(cand)
        if b'NNS{' in fb:
            pr("[+][+][+] FLAG:",fb.decode(errors='replace')); sys.exit(0)
pr("[-] no flag; dump:")
for X in (X0,X0-q):
    pr(repr(long_to_bytes(int(((X%p)*inverse_mod(sk,p))%p))[:64]))
