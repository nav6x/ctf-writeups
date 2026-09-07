# Pingbox (Niphers 3.0 CTF, web)

Pingbox lets you paste a link and fetches an oEmbed preview for it, with no allowlist at all. So I hosted my own fake page on webhook.site carrying the oEmbed discovery `<link>` tag, and the bot happily came and fetched it.

The server does validate the `iframe` src inside the returned HTML: it requires the same host as the page, which is why a YouTube src got rejected. But there's a separate `iframe_url` field that gets zero validation, and it flows straight into a data attribute. The client-side unfurl JS reads that attribute on click, creates an iframe with `sandbox="allow-scripts allow-same-origin"`, inserts it into the DOM *first*, and sets the `src` *after*. That ordering is the whole bug: the frame is already `about:blank` inheriting the parent origin, and navigating it to a `javascript:` URI runs that script in the parent's origin. With `allow-scripts` and `allow-same-origin` both set, the sandbox does nothing.

So I set the `javascript:` payload to grab `parent.document` and append a `<script>` tag pointing at my webhook, then reported the chat. The headless-Chrome admin clicked the preview, my payload ran in the top document, and since there was no CSP and the cookie wasn't `HttpOnly`, `document.cookie` handed itself straight over.

Flag: `$N1PH€RSxTCTF{3sc4p1ng_S4ndB0x_15_M4d3_3z!!}`
