from sim import test_string, build_body, parse, varint
T = "A cold beer  " + "is the finest lager one could ever want"
base = list("this is a beer  cold golden lager brew tasty yum")
base = base[:48] + [' ']*(48-len(base))
base[15] = ' '
T = ''.join(base)
assert len(T)==48, len(T)
assert T[15]==' '
ok,total,rows,n = test_string(T, approved=True)
print("T=",repr(T))
print("len",len(T),"idx15",repr(T[15]),"idx11..14",repr(T[11:15]))
print("parse ok=",ok,"counted+=",total,"rows=",rows)
