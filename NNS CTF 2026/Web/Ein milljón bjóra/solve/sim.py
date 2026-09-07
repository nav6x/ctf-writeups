
def varint(n):
    out=bytearray()
    while True:
        b=n&0x7f; n>>=7
        if n: out.append(b|0x80)
        else: out.append(b); break
    return bytes(out)

def read_varint(buf,i):
    shift=0; res=0
    while True:
        if i>=len(buf): raise EOFError
        b=buf[i]; i+=1
        res|=(b&0x7f)<<shift
        if not (b&0x80): break
        shift+=7
    return res,i

def build_body(S_bytes, approved):
    return b'\x01\x00\x00\x00'+varint(len(S_bytes))+S_bytes+bytes([1 if approved else 0])

def parse(body):
    """Return (ok, total_counted, nrows) mimicking ClickHouse RowBinary."""
    i=0; total=0; rows=0
    while i<len(body):
        start=i
        if i+16>len(body): return (False,0,rows)
        i+=16
        if i+4>len(body): return (False,0,rows)
        amount=int.from_bytes(body[i:i+4],'little'); i+=4
        try:
            Lc,i=read_varint(body,i)
        except EOFError: return (False,0,rows)
        if i+Lc>len(body): return (False,0,rows)
        i+=Lc
        if i+1>len(body): return (False,0,rows)
        approved=body[i]; i+=1
        rows+=1
        if approved: total+=amount
    return (True,total,rows)

def test_string(S, approved=True):
    b=S.encode('utf-8')[:100]
    body=build_body(b,approved)
    ok,total,rows=parse(body)
    return ok,total,rows,len(b)

if __name__=='__main__':
    import sys
    for s in ["Lager","Guinness Stout"]:
        print(repr(s), test_string(s))
    S=list("ABCDEFGHIJK"+"WXYZ"+" "+"z"*32)
    S=''.join(S)
    print("len",len(S),"idx15",repr(S[15]))
    print(repr(S), test_string(S))
