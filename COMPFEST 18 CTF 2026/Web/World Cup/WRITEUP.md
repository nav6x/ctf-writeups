# World Cup (COMPFEST 18, web)

This is a ticket site with a match page. Hitting `id=1` with a stray quote throws a MariaDB error that leaks the whole query and tells you it has 12 columns, so a `UNION SELECT` injection is right there. The twist is that you can't read the flag directly, you have to write a file to turn the injection into SSTI.

The key detail is that `secure_file_priv` is set to `/app/templates`, which means I can't `LOAD_FILE` the flag from `/`, but I *can* write files into that templates folder, and that's the whole trick. The audit logs in the app spell it out: a "promo final week" feature wants a live promo HTML template that doesn't exist yet, and Flask will render it if it's there. So if I drop my own Jinja into that path, it's server-side template injection.

So I `UNION SELECT`ed my payload into `/app/templates/live_promo.html` using `INTO DUMPFILE` rather than `INTO OUTFILE` (`OUTFILE` mangles newlines and breaks the template, while `DUMPFILE` writes the bytes verbatim). Then hitting the "promo final week" route renders my template, and `lipsum.__globals__.os.popen` runs and cats the flag straight out. The suffix rerolls per instance, so submit while the instance is live.

Flag: `COMPFEST18{Messi_Messi_Messi_Encara_Messi_yacpAogTEhNzbTJw}` (per-instance suffix)
