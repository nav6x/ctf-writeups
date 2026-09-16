from pathlib import Path

p = Path(__file__).resolve().parent.parent / "handout" / "out.pkl.part"
if not p.exists():
    p = Path("out.pkl.part")
data = open(p, "rb").read()

def read_long1_at(idx):
    ln = data[idx + 1]
    raw = data[idx + 2 : idx + 2 + ln]
    return int.from_bytes(raw, "little", signed=True), idx + 2 + ln

i = data.index(b"secret\x94") + len(b"secret\x94")
secret, _ = read_long1_at(i)

def get_val(keybytes):
    i = data.index(keybytes)
    j = i + len(keybytes)
    while data[j] != 0x8A:
        j += 1
    v, _ = read_long1_at(j)
    return v

v = get_val(b"the flag")
num = v ^ secret
flag = num.to_bytes(-(num.bit_length() // -8)).decode()
print(flag.replace("SCONES", "K17"))
