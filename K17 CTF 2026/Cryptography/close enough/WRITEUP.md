# close enough (K17 CTF, crypto)

We're given an incomplete download `out.pkl.part` and the source file `ekv.py` that produced it, with the prompt noting that the download got stuck halfway through.

## The storage model

`ekv.py` implements a simple dictionary-like key-value store where every value is XORed against a single shared integer:

```python
class EncryptedKV:
    def __init__(self, secret):
        self.secret = secret
        self.d = {}

    def __getitem__(self, key):
        num: int = (self.d[key] ^ self.secret)
        return num.to_bytes(-(num.bit_length() // -8)).decode()

    def __setitem__(self, key, value):
        self.d[key] = int.from_bytes(value.encode()) ^ self.secret
```

Because `out.pkl.part` cuts off before the stream finishes, running `pickle.load()` immediately blows up with an `UnpicklingError` / `EOFError`. But Python's pickle format is a sequential stream of opcodes, and data serialized before the cutoff point is still sitting in the file intact.

## Parsing opcodes manually

A hex dump of `out.pkl.part` reveals standard pickle protocol 4:

1. `secret` is stored right after the memoized key `b'secret'` as a `LONG1` opcode (`0x8a`).
2. Dictionary entries follow as `<key string><MEMOIZE><LONG1 int>`.
3. The stream cuts off inside the final entry (`"admin password for the scoreboard"`), but `"the flag"` was written earlier and is completely intact.

We can scan forward through the raw bytes to pluck out `secret` and the encrypted integer for `"the flag"`, XOR with `secret`, and convert back to bytes:

```python
data = open("out.pkl.part", "rb").read()

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
```

The author's internal wrapper was `SCONES{y0u_got_m3_out_of_a_p1ckle}`, which maps to the CTF flag format `K17{y0u_got_m3_out_of_a_p1ckle}`.

Solve: `solve/solve.py`

Flag: `K17{y0u_got_m3_out_of_a_p1ckle}`
