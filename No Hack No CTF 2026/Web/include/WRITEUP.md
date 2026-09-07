# #include (No Hack No CTF, web)

"Yet another PDF converter. easy enough, right?", and the flag is in the source code. That last part is literal: the service renders any URL to a PDF with headless Chromium, there's no server-side scheme allow-list, so you feed it `file://` URLs and read local files, and the flag is a comment at the bottom of `server.js`.

Flag: `NHNC{Well_done!_stay_tuned_for_the_next_challenge.}`.

## Recon

The page is a URL-to-PDF converter: submit a URL, get back a rendered PDF. The client-side `main.js` only validates the URL against `/^https?:\/\//i`, which is cosmetic, the server does its own thing and never sees that check. `/captcha-config` returns `{"enabled":true,"siteKey":"6LdH30MtAAAAAH4DIcrw8eNgRi03QhnRJmEXfGxG"}`, so the one dynamic endpoint, `POST /convert`, is gated behind Google reCAPTCHA v2. Everything else is static or 404.

## The captcha is real

The obvious shortcuts don't work here, and it's worth knowing that so you don't waste time. Google's public test secret/test token fails (the server uses its real secret). Parameter pollution in the token doesn't inject anything because the server does a clean `URLSearchParams` POST to `/siteverify`. Magic values ("test", "true", the site key itself) all fail. Content-type and body-parsing tricks still hit the captcha check. And a timing test shows a ~35ms latency bump when a token is present, meaning the server genuinely calls Google's `/siteverify`. So the captcha has to actually be solved with a valid token.

The saving grace is that reCAPTCHA v2 checkbox tokens are single-use and short-lived (about two minutes), and this particular site key is configured at low security, clicking the checkbox passes instantly with no image challenge. So the whole "hard" part is just: drive a real browser, click the box, grab the token from `grecaptcha.getResponse()`, and submit `/convert` before the token expires. You can do it by hand and quickly reuse the token with curl, or automate it with puppeteer-core against an installed Chrome. Either way, submitting `/convert` with `url=file:///etc/passwd` and a fresh token returns a real PDF whose text is the contents of `/etc/passwd`. That confirms the `file://` LFI. Pull the text back out with `pdftotext` or `pdfminer.six`.

## Reading the server source without guessing paths

`/etc/passwd` shows a standard Node Docker image, a `node` user with `/home/node`, plus a `ctf` user. The obvious next step, guessing the install path (`/app`, `/usr/src/app`, and so on), fails: the app returns a 500 "conversion failed" both for files that don't exist and for directories (Chromium won't render a directory listing).

The trick that sidesteps all the guessing is `/proc/1/cwd/`, the working directory of PID 1, which is the Node app itself. Read `file:///proc/1/cwd/package.json` first to learn the entry point; it comes back as `{"name":"include","scripts":{"start":"node server.js"},...}`. So the entry file is `server.js` in that same directory, and `file:///proc/1/cwd/server.js` renders the full server source into a PDF. Use the standard converter rather than any "lite" style, directory listings and lite mode render poorly, and extract with `pdfminer.six` for clean text.

At the very bottom of `server.js`, inside a little ASCII-art starfield comment block, sits the flag.

## The twist

The one server-side protection against local file reads is a helper, `points_to_local_directory(url)`, that rejects a `file://` URL only when it `stat()`s to a directory. Individual files are fully allowed. Combined with `/proc/1/cwd/` resolving the app's real working directory, you never need the absolute install path or any brute force. You just walk straight to the source and read the flag out of a comment, exactly as the description promised.

Flag: `NHNC{Well_done!_stay_tuned_for_the_next_challenge.}`
