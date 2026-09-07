# EGG (COMPFEST 18, web)

EGG is a WordPress 7 box, and I recognized it as the "WP2Shell" chain right away. The path is a request-smuggling-style route confusion into a SQL injection, then a well-known WordPress gadget chain to mint an admin, and finally a plugin-upload web shell.

The entry point is a batch request with a malformed URL like `http://:80`, which breaks WordPress's route matching so your request executes on a different handler than intended. That misrouting is what turns the `author_exclude` parameter into a full SQL injection. There was a WAF this time, but it only blocked the obvious `AND 1=1`-style patterns, so I used `AND 1=0 UNION` instead and it went straight through.

With injection working, I abused the oEmbed cache together with the customizer changeset gadget to promote myself to an admin user. Logged in as that admin, I uploaded a tiny plugin ZIP containing a web shell, which gave code execution as `www-data`, and `cat /flag.txt` finished it.

Flag: `COMPFEST18{th3_3gg_h4s_h4tch3d_KkaNFdqUMVXAiTxj}`
