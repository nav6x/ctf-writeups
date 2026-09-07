# Madness (TraceBash CTF, web)

A web challenge whose whole design is misdirection: it dangles an obvious SQL-injection-to-admin path that turns out to be a dead end, while the real flag is hidden in a file served to everyone.

I registered, logged in, and found `/admin_only` returning access denied. The login form had a SQL injection, and `admin'-- -` bypassed it and logged me in as admin. The admin page showed a "TOP SECRET" password `M4dn3sS!` and a lot of trolling about `robots.txt`, all of which is there to burn your time. Dumping the database through the SQLi is the overthinking trap the challenge name is hinting at.

The actual trick was the favicon. `favicon.ico` wasn't a normal icon, it was a JPEG image served to every visitor, hiding in plain sight. That's the carrier. Running `steghide extract` on the favicon using the password `M4dn3sS!` from the admin page pulled the flag straight out. So the admin password was real and needed, but only as the steghide passphrase, not for any database work.

One environment note: `steghide` isn't available via Homebrew, so I ran it inside a Debian container to do the extraction.

The lesson is to notice when assets that should be static (an icon, a logo) are actually a different file type than they claim, and to treat a recovered password as a possible key for stego rather than assuming it unlocks the obvious thing.

Flag: `TBCTF{1_5u5p3c7_y0u_4r3_4n_0v3r7h1nk3r}`
