# Old website (BushBash CTF, web)

The premise is that a website is still running on one of cybervillain Zoowee Blubberworth's old domains, "supposed to be in jail right now," and "it probably hasn't been updated in a year or so", go hack in and have a peek around. That "not updated in a year" line is doing double duty, which I only appreciated after it bit me: it means an outdated framework with a known CVE, and it also means a literal one-year HTTP cache TTL sitting in front of the site that actively sabotages the exploit until you route around it.

Flag: `bushbash{youWillNeverCatchMe!IDugATunnelOut}`, Zoowee's little joke about digging a tunnel out of jail.

## Recon and the version fingerprint

The homepage at `http://34.40.133.67:8080/` is a Next.js App-Router SSR page, `X-Powered-By: Next.js`, a batch of `x-nextjs-*` headers, and the body just reads "No content loaded - database offline." The one header that jumps out is `Cache-Control: s-maxage=31536000`, and 31536000 is exactly one year in seconds. File that away.

Brute-forcing routes went nowhere: `/admin`, `/login`, `/api`, `/flag` and friends all return the App-Router 404, `POST /` returns 405, and directory fuzzing over `/` and `/api/` only turned up 308 redirects for junk. Static assets under `/_next/static/` serve fine, though, and that's the decisive move. Downloading the client JS chunks and grepping for version strings gives `version:"15.0.4"` for Next.js and `version:"19.0.0-rc-66855b96-20241106"` for React, a November 2024 build. (Later, once I had code execution, `/app/package.json` confirmed it and even carried `"description": "react2shell chal"`, which is about as on-the-nose as challenge authors get.)

Version fingerprinting from static chunks is the whole recon here, because Next.js 15.0.0 through 15.0.4 with the bundled React 19 RC is vulnerable to what people started calling "React2Shell": CVE-2025-55182 on the React side, tracked as CVE-2025-66478 in the Next.js advisory. It's an unauthenticated RCE, patched in 15.0.5+ / 15.2.3+.

A port scan of the host found 80/443 (an ingress-nginx fronting a GKE cluster) and a curious 7777 serving a "self-serving hash browns machine" password banner, a different challenge entirely, noted and ignored.

## The vulnerability

The root cause is server-side prototype pollution in the React Server Components "flight" deserialization logic (`react-server-dom-webpack`). When Next decodes a Server Action request, the RSC parser resolves attacker-controlled reference tokens, things like `$1`, `$B3`, or the interesting ones, `$1:__proto__:then` and `$1:constructor:constructor`, while walking a `multipart/form-data` body. Because you can steer that walk down the prototype chain to `constructor.constructor` (the `Function` constructor) and hand it attacker JS as the function body, you get arbitrary Node code execution.

The important structural detail is that this fires during *decode*, before any real action runs, so the app doesn't need to have a registered Server Action at all. The trigger surface is just a POST carrying a `Next-Action:` header (any value) and a `multipart/form-data` body. That's enough to route the request into the action-decoding path where the malicious reference graph gets evaluated.

Confirming the parser was reachable was a one-liner: POST to `/` with `Next-Action: x` and a field `{"then":"$1:__proto__:constructor:constructor"}`. The response was a 500 with `Content-Type: text/x-component` and a serialized error chunk `1:E{"digest":"2649741193"}`. That's not a generic 405/404: the request reached the RSC flight parser, it threw, and React serialized the error as an `E` chunk with a `digest`. That both proves reachability and, as it turns out, hands you the exfil primitive you'll need later.

## Two blockers, and the dead ends that revealed them

This is where the challenge earns its points, because the public PoCs did not just work. When I fired dev-oriented gadgets (the pkrasulia-style fields-0-through-5 structure, the Datadog two-field structure) at `/`, the response came back as the *cached* 200 homepage, `x-nextjs-cache: HIT`, served in about 0.4s. The payload wasn't executing at all. A busy-wait timing oracle (`var e=Date.now()+8000;while(Date.now()<e){}`) produced no delay across many tries, confirming no code was running. One apparent 8-second delay early on turned out to be cold-start noise, not my payload.

There were two real reasons, and both matter.

The first is that ISR cache. The homepage is prerendered with `s-maxage=31536000`, so POSTs to `/` were being answered straight out of the one-year cache without ever running the action decode. That's the "not updated in a year" hint made mechanical. The fix is simple once you see it: POST to a random, non-cached path like `/x1a2b3c4d`. Next still routes it into the RSC action-decode path, but there's no cached prerender to short-circuit it.

While chasing this I briefly worried that the RSC internal property names (`_prefix`, `_formData`, `_response`, `_chunks`) would be minified away in a production build, making the gadgets unusable. That's false. Terser doesn't mangle object property names by default, so those names survive in prod. The gadget shape was fine all along; the cache was the problem.

The second blocker was exfiltration: even once code ran, I had no way to see its output, which made "did it run?" ambiguous. Three exfil channels failed, and each failure taught me something about the environment:

- Writing output to disk under paths Next serves (`.next/static/...`, `public/...`) and fetching them back over HTTP. Every fetch returned the 404. In this standalone-ish build Next only serves build-manifested hashed assets, not arbitrary files dropped there.
- Patching `http.ServerResponse.prototype` to inject an `x-out` response header. The header never appeared. The RCE runs in a Next render worker that's a *separate process* from the one flushing HTTP responses, so a prototype patch in the worker never touches the response-facing process (and the homepage is cached anyway).
- Out-of-band exfil to a webhook.site token via node `https` or `curl`. No callback ever arrived. Timing oracles to `1.1.1.1:443` and DNS lookups showed no delay, so outbound egress from the pod is firewalled off entirely.

The lesson from all three is the same: with egress blocked, the render worker split from the HTTP process, and an aggressive response cache, the only reliable channel is *in-band*, through the action response itself.

## The working exploit

Two ideas combine into something reliable. First, POST to a random path so the ISR cache is bypassed and the action-decode path actually runs. Second (this is the neat part), exfiltrate output through the thrown error's `digest`. React serializes a thrown error's `digest` property into the flight response even in production; the message is hidden but the digest passes through. So the payload runs the command, base64-encodes the output, and throws it back:

```js
var cp = process.mainModule.require('child_process');
var c  = Buffer.from('<CMD_BASE64>','base64').toString();
var res;
try   { res = cp.execSync(c, {encoding:'base64', timeout:20000}); }
catch (e) { res = Buffer.from('ERR:'+e.message+'|'+(e.stdout||'')+'|'+(e.stderr||'')).toString('base64'); }
throw Object.assign(new Error('x'), { digest: res });
```

Delivering the command base64-encoded and decoding it server-side sidesteps all the quoting problems of embedding shell (quotes, pipes, semicolons) inside multipart-inside-JSON, so arbitrary shell just works.

The multipart body is three fields. Field `0` is the gadget: it sets `then` to `$1:__proto__:then`, marks itself `resolved_model`, and stashes the JS payload in a `_response` object whose `_formData.get` is the reference `$1:constructor:constructor`. That's what resolves to the `Function` constructor when the parser walks it, turning `_prefix` (the JS) into a callable. Field `1` is `"$@0"` referencing field 0, and field `2` is an empty `[]`. The request carries `Next-Action: x` and the multipart content type, and goes to a fresh random path each time:

```
POST /<random>  HTTP/1.1
Next-Action: x
Content-Type: multipart/form-data; boundary=----NextRceMitsecOps
```

The response is a 500 with `Content-Type: text/x-component` containing `1:E{"digest":"<base64 of command output>"}`. You pull the digest out with `/"digest"\s*:\s*"([^"]*)"/` and base64-decode it. The whole thing is a short pure-`urllib` script, no third-party deps, that takes a shell command as an argument.

## Getting the flag

`id; hostname; pwd; uname -a` came back as `uid=1000(node)`, hostname `old-website-85764775f9-d6j26`, cwd `/app`, Linux 6.12, RCE as `node` inside a Kubernetes pod on Node v26.5.1. Listing `/app` showed the trivial app (`layout.jsx`, `page.jsx`, no DB, no userland action) plus a 45-byte `zoowee_message.txt` that the author had planted. Reading it:

```
bushbash{youWillNeverCatchMe!IDugATunnelOut}
```

A `grep -rIn bushbash /app` confirmed that was the only copy on disk. The pod's environment incidentally exposed a row of sibling challenge services (cachebrowns, hack-the-vault, strawberries, and others) as Kubernetes service-link vars on port 1337, and confirmed the app listens internally on 1337 with ingress mapping 8080 to it. None of that was needed.

## What to take away

Static JS chunks fingerprint the framework version precisely, and that's what unlocks the CVE choice. The story's "not updated in a year" is a genuine double hint, an old vulnerable version *and* a literal `s-maxage=31536000` cache you have to bypass by hitting a fresh path. Dev PoC gadgets translate cleanly to production once you realize terser keeps property names; the blockers were never the gadget. And the exfil trick is the reusable one: when egress is firewalled and the render worker is a separate process from the HTTP responder, abuse React's `Error.digest` serialization to smuggle base64 output back in-band. The fix, as always, is to upgrade Next.js to 15.0.5 or later (ideally 15.2.3+) with the patched React.

Flag: `bushbash{youWillNeverCatchMe!IDugATunnelOut}`
