from secrets import randbelow
from Crypto.Util.number import bytes_to_long, long_to_bytes, getPrime
from sage.all import *

flag = b"NNS{????????????????????????????????}"

q, t = 2**768, 2**512
n, m, w, b = 16, 112, 130, 16
R = Zmod(q)

def keygen():
    s = random_vector(R, n)
    r = getPrime(32)
    p = getPrime(520)
    sk = getPrime(128)

    A = random_matrix(ZZ, m, n, x=0, y=b)
    e = random_vector(ZZ, m, 0, r)
    k = R(p)/sk
    B = A*s + k*e

    return (A, B)

def encrypt(pk, pt):
    A, B = pk
    I = [ZZ.random_element(m) for _ in range(w)]
    return sum(A[i] for i in I), pt - sum(B[i] for i in I)

pk = keygen()
ct = encrypt(pk, bytes_to_long(flag))

print(f"pk = ({pk[0].list()}, {pk[1]})")
print(f"ct = {ct}")