# PHP is my passion (NNS CTF, web)

This one is a known-CVE challenge: the target runs phpBB 3.3.16 configured with the Apache authentication provider, which is vulnerable to CVE-2026-48611, an authentication bypass.

The setup matters. phpBB can delegate login to Apache's own auth via the `apache` auth provider instead of its normal database login. CVE-2026-48611 is a flaw in how that provider validates the authenticated user, and it lets you authenticate as an existing account without supplying valid credentials. The account you want is the administrator.

So the exploit is: trigger the Apache-auth-provider bypass to log in as the admin, then read the administrator's private messages. The flag is waiting in a PM there rather than anywhere in the public forum.

Because it's read live against a running instance, the flag is instance-specific and there's no local solve script; the challenge source (the Docker setup, phpBB config, and `seed.php`) is in `handout/`, and the shipped source only contains the placeholder `NNS{test_flag}`.

The takeaway is a boring but real one: keep forum and CMS software patched, and be especially careful with non-default auth providers, since they widen the attack surface in ways the main project may not test as thoroughly.

Flag: read live from the admin's private messages (instance-specific)
