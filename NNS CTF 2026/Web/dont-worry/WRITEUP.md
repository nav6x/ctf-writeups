# dont-worry (NNS CTF, web)

A note-taking app with share-by-link and an admin bot that holds the flag. Getting it means chaining three things: running your own JavaScript same-origin under a strict CSP, reading a document with the wrong key by abusing the browser's HTTP cache, and exfiltrating without any server of your own.

First, how the app works. You create a document with a random `id` and `key`, and the reader page at `/d/<id>#<key>` fetches the document and does `doc.innerHTML = data.body`. There's also `/raw/<id>?key=<key>`, which returns the raw body with a `Content-Type` chosen from the document's `language` field. The API sits at `/api/documents/<id>?key=<key>&view=editor|reader`, and the `key` is genuinely required: wrong key, missing key, or hitting `/raw` without it all return 403.

The admin bot creates a `welcome` document whose body is the flag, using a random UUID key you never see, then opens the editor for it (which caches the response), closes the page, sleeps 15 seconds, and finally visits a same-origin URL you supply. The flag's key only ever appears in the URL fragment, so it's never sent to the server and never persisted anywhere you can read.

The response headers are where it gets interesting. Every API response carries `Cache-Control: private, max-age=5` and `No-Vary-Search: params, except=("view")`, and the CSP is `script-src 'self'` with no `unsafe-inline`. Two consequences fall out. `No-Vary-Search` tells the browser cache to ignore every query parameter except `view`, which means `?key=SECRET&view=editor` and `?key=anything&view=editor` map to the same cache entry. And `max-age=5` makes that entry fresh for only five seconds, while the bot deliberately waits fifteen, so a normal fetch would revalidate and 403 with your wrong key. That 5-versus-15 gap is the trap.

The first primitive is JavaScript execution from `'self'`. A bare `<script>` inserted through `innerHTML` doesn't run, and inline event handlers like `onerror=` are blocked by the CSP, so ordinary DOM XSS is dead. But `/raw` returns `text/javascript` when the document's language is `javascript`, so a document you control can be loaded as a same-origin script, which `script-src 'self'` allows. To actually trigger it through the reader's `innerHTML` sink, deliver an iframe with `srcdoc`: `<iframe srcdoc='<script src="/raw/payloadreal?key=pkey123"></script>'></iframe>`. The `srcdoc` is parsed as a full same-origin document inheriting the parent CSP, and an external same-origin `<script src>` inside it runs normally.

The second primitive is reading the flag with the wrong key after the TTL lapsed. When the bot opened the editor, the flag response got stored under a cache key that ignores `key`. Fifteen seconds later it's stale, but `fetch(url, {cache: 'force-cache'})` returns a stored response regardless of freshness, and `No-Vary-Search` lets your bogus `key=k` match the entry the bot cached under the real UUID. So the fetch comes back with the flag in the body.

The third primitive is serverless exfiltration. Your JavaScript runs same-origin, so it just `PUT`s the stolen body into a document you own, which you then read back over plain HTTP with your own key.

Putting it together: create three docs up front, a `javascript`-language payload doc that reads `welcome` with `force-cache` and copies the body into an `exfilbox` doc, a host doc whose body is the iframe that loads the payload, and the empty `exfilbox`. Submit `/d/hostreal#hkey123` to the bot. The bot caches the flag, waits out the TTL, opens your host doc, the iframe runs your payload same-origin, the `force-cache` read returns the flag, and it lands in `exfilbox`, which you read back at your leisure.

I validated the whole chain locally with a planted test flag before spending an admin-bot run, then repointed it at `welcome`.

Solve: `solve/solve.sh` (one-shot: creates the docs, prints the bot URL, polls exfilbox)

Flag: `NNS{A_Wise_guY_froM_s0meWh3re_faR_N0r7H_0NC3_t01D_M3:_doNt_worRy_aB0u7_1t}`
