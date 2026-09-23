# GitGraves_MU (Security Impossible CTF 2026 - Monash University, misc)

We are given a compressed archive `public_repo.tar.gz` containing a Git repository for a deployment service named `acme-deploy`. The description indicates that an operator mistakenly committed production credentials before attempting to scrub the repository by deleting the branch and forcing a garbage collection cleanup. Our task is to perform Git database archaeology and recover the discarded data.

## Git Architecture and Dangling Objects

In Git, all versions of files, directories, and commits are stored as immutable content-addressable objects in `.git/objects`:
- `commit`: References a root tree object, parent commits, author, committer, and commit message.
- `tree`: Represents a directory listing, mapping file names to blob or tree hashes.
- `blob`: Stores raw file contents.

When a branch is deleted via `git branch -D` or rewritten via `git reset --hard`, Git removes the reference pointing to the tip commit. In addition, reflogs (`.git/logs/`) can be pruned or deleted. However, the underlying object files on disk remain completely untouched until Git runs an aggressive pack-file garbage collection pass (`git gc --prune=now`). 

Until that occurs, these commits exist as "dangling" or unreachable objects.

## Finding Dangling Commits with Git Plumbing

We extract the repository and run `git fsck` (file system check) with `--full` and `--no-reflogs` to verify the object database and locate unreferenced root commits:

```bash
tar -xzf public_repo.tar.gz
cd acme-deploy
git fsck --full --no-reflogs
```

The output identifies several unreachable objects:

```text
dangling blob 31f92e8a1040854d6fa7c644d85261176e5d8a90
dangling commit 8ebb16cd275566071432715f38a97ab6d181946a
dangling tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904
```

## Inspecting the Commit

We inspect the dangling commit using `git show`:

```bash
git show 8ebb16cd275566071432715f38a97ab6d181946a
```

The commit diff reveals an additions block in `deploy/prod_secrets.env`:

```diff
commit 8ebb16cd275566071432715f38a97ab6d181946a
Author: DevOps Lead <devops@acme.example>
Date:   Mon Sep 21 14:22:01 2026 +1000

    deploy: temporary commit with deployment secrets

diff --git a/deploy/prod_secrets.env b/deploy/prod_secrets.env
new file mode 100644
index 0000000..7a2e81b
--- /dev/null
+++ b/deploy/prod_secrets.env
@@ -0,0 +1,3 @@
+DEPLOY_ENV=production
+API_KEY=sictf{d4ngl1ng_0bj3cts_n3v3r_d13}
+DB_PASS=supersecretproductionpwd
```

The flag is contained directly inside the deleted `API_KEY` definition.

Flag: `sictf{d4ngl1ng_0bj3cts_n3v3r_d13}`
