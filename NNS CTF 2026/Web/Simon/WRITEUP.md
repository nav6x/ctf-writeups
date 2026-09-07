# Simon (NNS CTF, web)

This one is a client-side auth bypass, where a restriction that's supposed to protect something only exists in the browser and was never enforced on the server.

The seat-booking UI disables the "Save" button for seats marked "premium", so through the interface you can't book one. But that check lives entirely in the client-side JavaScript. The server's `/save` endpoint happily accepts a booking for any seat, premium or not, because it never re-checks what the browser was hiding.

So skip the UI and talk to the endpoint directly. Keep a cookie jar so your session sticks, then save a premium seat yourself:

```
POST /save   {"seat":"3B"}     # any available premium seat, rows <= 4
GET  /                          # reload
```

One subtlety worth noting: the `POST` on its own only returns `{"flag":true}`, a boolean that tells you it worked but doesn't contain the flag. The actual flag is rendered into the page (the "NNS Air Plus" panel) when you reload `/` afterward, so you need the follow-up `GET`.

The general point is the same as most client-side bypasses: anything the browser can disable, the client can re-enable. Every rule that matters has to be checked again on the server.

Solved live over HTTP, no local files.

Endpoint: `https://simon-*.chall.nnsc.tf`

Flag: `NNS{We_wi5h_y0u_a_Pl3as4Nt_F1igh7_w17H_NN5_a1r}`
