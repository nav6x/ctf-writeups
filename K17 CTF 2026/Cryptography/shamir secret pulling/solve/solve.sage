from sage.all import GF, Matrix, vector, ZZ, QQ, is_prime
from pathlib import Path

def long_to_bytes(n):
    n = int(n)
    return n.to_bytes((n.bit_length() + 7) // 8, "big")

p = Path(__file__).resolve().parent.parent / "handout" / "out.txt"
if not p.exists():
    p = Path("out.txt")

txt = open(p).read()
ns = {}
exec(txt, ns)
MOD = ns["MOD"]
B = ns["B"]
known = ns["known"]
new = ns["new"]

F = GF(MOD)
N = 32

kx = [F(x) for x, _ in known]
kv = [F(v) for _, v in known]

def P_eval(X):
    X = F(X)
    s = F(0)
    for i in range(len(kx)):
        term = kv[i]
        for j in range(len(kx)):
            if j != i:
                term *= (X - kx[j]) / (kx[i] - kx[j])
        s += term
    return s

rows = []
b = []
for x, px in known:
    X = F(x)
    rows.append([X**i for i in range(N)])
    b.append(F(0))
for x, qx in new:
    X = F(x)
    rows.append([X**i for i in range(N)])
    b.append(F(qx) - P_eval(x))

A = Matrix(F, rows)
bvec = vector(F, b)
dp = A.solve_right(bvec)
ker = A.right_kernel().basis()

dp_int = vector(ZZ, [int(x) for x in dp])
gens = [[int(c) for c in kvec] for kvec in ker]
for i in range(N):
    row = [0] * N
    row[i] = int(MOD)
    gens.append(row)
L = Matrix(ZZ, gens).LLL()
Lb = Matrix(ZZ, [r for r in L.rows() if not r.is_zero()])

G = Lb.gram_schmidt()[0]
t = vector(QQ, dp_int)
for i in reversed(range(Lb.nrows())):
    gi = G[i]
    c = round((t * gi) / (gi * gi))
    t = t - c * Lb.rows()[i]
D = vector(ZZ, [int(round(x)) for x in t])

Q0 = P_eval(0) + F(D[0])
print(long_to_bytes(int(Q0)).decode())
