# File Monster (NNS CTF, web)

The intended flag lives only in environment variables and in a file you get to author yourself, and pulling it out means chaining a quirky upload endpoint with a genuinely surprising file-read primitive inside MongoDB's server-side JavaScript.

Start with the upload. `POST /upload` writes attacker-controlled text to `/tmp/<name>`, where the name has to match `^[a-zA-Z][a-zA-Z0-9.]*$`. Before writing, it strips the characters `"`, `'`, and backtick, and it replaces the first occurrence of the literal `FLAG` with `process.env.FLAG`. So you can drop an arbitrary quote-free file into `/tmp`, and if it contains the word `FLAG`, the real flag gets substituted right into your file.

Next, the database. You're given a `viewer/viewer` MongoDB account that's read-only and JS-sandboxed, with no `fs`, `env`, or `exec` reachable. It looks locked down, but mongod 8.2.10's server-side JavaScript engine (SpiderMonkey) has a working `import()`. Calling `import('/tmp/x')` makes mongod itself `openat()` and load the file as an ES module, and since Bun (the web app) and mongod share the container's `/tmp`, mongod will read files you uploaded. That's the file-read primitive the whole challenge hinges on, and it's available to a plain read-only user.

There's a timing wrinkle. Inside a `$function`, the import Promise never settles because there's no event-loop drain, so the module never actually evaluates. But inside a multi-document `mapReduce`, the JS job queue does drain between map invocations, and `globalThis` persists across those calls within a single query. So if you run the import from a `mapReduce` over at least two documents, the module evaluates and its side effects become visible on the second and later map calls.

Now exfiltration, keeping in mind you can't use quotes. Upload a wrapper module whose body is `globalThis.__LK = (/FLAG/).source`. After the server's `FLAG` substitution that becomes `globalThis.__LK = (/NNS{...}/).source`, and a regex literal's `.source` property is exactly its pattern text as a string, no quotes required. Import that module from the mapReduce, then read `globalThis.__LK` back through the drain and you have the flag.

Worth recording as reusable primitives for MongoDB-JS challenges: mongod 8.2's server-side `import('/abs/path')` is an arbitrary server-side file open-and-parse available to a read-only user; `$function` has no event loop but `mapReduce` over multiple docs drains microtasks and shares `globalThis`, which is how you observe async results; and a regex literal's `.source` is a clean way to capture a string when quotes are filtered out.

The breakthrough came from a local Docker rebuild where an strace of mongod during a viewer `import('/tmp/flag')` showed the `openat(..., "/tmp/flag", O_RDONLY)`, which confirmed the primitive. The full investigation log (everything that was ruled out) and the working exploit are in `solve/SOLVED.md` and `solve/exploit3.py`.

Flag: `NNS{60oD_Job_g3ttiN6_7hi5_tas7y_fla6_fr0m_7he_Fla6_m0ns7er}`
