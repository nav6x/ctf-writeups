import subprocess
import os
from pathlib import Path

src = Path(__file__).resolve().parent.parent / "handout" / "etchasketch"
if not src.exists():
    src = Path("etchasketch")

with open(src, "rb") as f:
    data = bytearray(f.read())

data[0x3020] = 0

out_bin = Path(__file__).resolve().parent / "etchasketch_patched"
with open(out_bin, "wb") as f:
    f.write(data)

os.chmod(out_bin, 0o755)

try:
    res = subprocess.run([str(out_bin)], capture_output=True, text=True)
    if res.stdout:
        print(res.stdout)
except Exception:
    pass
