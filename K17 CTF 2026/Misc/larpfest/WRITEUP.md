# larpfest (K17 CTF, misc)

The challenge description links to a public repository at `https://github.com/larp-larp-larp/larp` with the prompt remarking: "The flag is (or was...) somewhere in this repo".

## Recovering orphaned commits via GitHub Events API

Cloning the repository and inspecting `git log` shows three commits:
1. `795d5d2` — `coding`
2. `afb99a4` — `oops`
3. `4df7ab7` — `the larp is unlimited`

The `.env` file on `main` contains a decoy string `OPENAI_API_KEY="please ignore"`. The commit message `oops` suggests a secret was committed and subsequently overwritten via a force-push.

A fresh clone only pulls commits reachable from remote refs. However, GitHub maintains an event audit trail and delays garbage collection on unreachable objects. Querying GitHub's public Events endpoint (`https://api.github.com/repos/larp-larp-larp/larp/events`) exposes a `PushEvent` with commit metadata:

- `head`: `afb99a4...`
- `before`: `2ff1293a0da908202dc16628e5c1fa68c05294ec`

The commit `2ff1293a0d...` is no longer on `main`, but GitHub still serves objects directly by hash:

```python
import urllib.request
import json
import re

url = "https://api.github.com/repos/larp-larp-larp/larp/commits/2ff1293a0da908202dc16628e5c1fa68c05294ec"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
data = json.loads(urllib.request.urlopen(req).read().decode())
patch = data["files"][0]["patch"]
flag = re.search(r"K17\{[^}]+\}", patch).group(0)
print(flag)
```

The diff for `.env` in that orphaned commit reveals the real key: `OPENAI_API_KEY="K17{l00k_im_a_1337_h4x0r}"`.

Solve: `solve/solve.py`

Flag: `K17{l00k_im_a_1337_h4x0r}`
