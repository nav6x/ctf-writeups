# GitDug_MU (Security Impossible CTF 2026 - Monash University, osint)

We are given a Git repository archive named `public_repo.tar.gz` for an open-source project called `webhook-relay`. The repository was recently scrubbed to remove accidentally leaked developer tokens before public release. Our task is to perform an OSINT audit of the repository commit history, recover the exposed token, and attribute the commit to the developer.

## Auditing Git History Beyond the Tip

A common misconception among developers is that deleting a secret in a new commit (`git rm` or editing the file and running `git commit`) removes the sensitive data from the repository. Because Git is an append-only distributed version control system, every commit retains an immutable snapshot of all files at that point in time. Unless the repository history is actively rewritten using tools like `git-filter-repo` or BFG Repo-Cleaner, previous commit snapshots remain accessible to anyone with clone access.

## Reviewing the Commit Log

We extract the archive and inspect the commit log across all branches, tags, and stashes:

```bash
tar -xzf public_repo.tar.gz
cd webhook-relay
git log --all --oneline --decorate
```

The log lists five commits:
- `3e8f102`: `docs: update readme with setup instructions`
- `a4c9012`: `security: scrub api tokens from configuration files`
- `91d7b7b`: `feat: add relay webhook dispatcher service`
- `f2098b1`: `init: initial repository scaffolding`

Commit `a4c9012` is titled "scrub api tokens from configuration files." This directly points us to the preceding commit `91d7b7b`.

## Extracting the Secret Diff

We inspect commit `91d7b7b` in detail:

```bash
git show 91d7b7b
```

The diff shows:

```diff
Author: Priya Nair <priya.nair@relay.example>
Date:   Wed Jul 15 11:04:19 2026 +1000

    feat: add relay webhook dispatcher service

diff --git a/config/relay.conf b/config/relay.conf
new file mode 100644
index 0000000..8fa321d
--- /dev/null
+++ b/config/relay.conf
@@ -0,0 +1,5 @@
+[relay]
+listen_host = 0.0.0.0
+listen_port = 8443
+auth_token = sictf{h1st0ry_r3m3mb3rs_y0ur_s3cr3ts}
+log_level = debug
```

The commit diff exposes the developer's identity (`Priya Nair <priya.nair@relay.example>`) and the plaintext authentication token, which matches the challenge flag.

Flag: `sictf{h1st0ry_r3m3mb3rs_y0ur_s3cr3ts}`
