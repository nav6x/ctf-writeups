def long_to_bytes(n):
    return int(n).to_bytes((int(n).bit_length()+7)//8, "big")
from itertools import combinations

P = (8556657727707208274959688356215492073697687136731745904584838792512887432513, 10499616004036352077827577187299579257617217465469948797372067456761225952316)
Q = (88180657532143901179801400727618544475583986813868807456575952256533937646251, 63821392431022588399657934703280620258227322035271046362557270025043176928410)
R = (2884294645399294720380774151786063792855454467820790044049756771962549273576, 45546238707907282017604068308740273108250809871556283061080241644830449119761)
C = (88072115282803413386990359870648890974288047092544455066184535919493069001195, 78478175560432097877707550454665012326974806492122263197710261539872842646450)

pts = [P, Q, R, C]

def det3(t):
    return Matrix(ZZ, [[x, 1, y^2 - x^3] for (x, y) in t]).det()

g = 0
for t in combinations(pts, 3):
    g = gcd(g, det3(t))
print("g =", g, g.nbits())

p = g
if not is_prime(g):
    for q, e in factor(g):
        if q.nbits() > 200:
            p = q
print("p =", p, p.nbits(), is_prime(p))

x1, y1 = P
x2, y2 = Q
M = Matrix(GF(p), [[x1, 1], [x2, 1]])
a, b = M.solve_right(vector(GF(p), [y1^2 - x1^3, y2^2 - x2^3]))
print("a =", a)
print("b =", b)

E = EllipticCurve(GF(p), [a, b])
for (x, y) in pts:
    assert E.is_on_curve(x, y), (x, y)
Pp, Qp, Rp, Cp = [E(*t) for t in pts]
print("2P==Q:", 2 * Pp == Qp, " 2Q==R:", 2 * Qp == Rp)

n = E.order()
print("n =", n)
print("factor(n) =", factor(n))

k = next_prime(0x133713371337)
ordC = Cp.order()
print("ord(C) =", ordC, gcd(k, ordC))
F = inverse_mod(k, ordC) * Cp
print("F =", F.xy())
print("flag =", long_to_bytes(int(F.xy()[0])))
