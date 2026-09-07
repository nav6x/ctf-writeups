# Web Hacker 2 (NNS CTF, web)

This is a textbook IDOR (Insecure Direct Object Reference), which is what you call it when an endpoint lets you ask for someone else's data just by naming them, because it never checks that you're allowed to.

The page loads a boarding pass by calling `GET /api/boarding-pass/john`, with the username `john` hardcoded in the client. The important part is on the server: that API takes whatever username is in the URL and returns that user's boarding pass without any authorization check. The client only ever asks for `john`, but nothing stops you from asking for someone else.

So you just ask for the admin instead:

```
GET /api/boarding-pass/admin
```

The response is JSON, and the flag is sitting in the `toName` field.

The lesson is that access control has to live on the server and has to be tied to who is actually making the request. Deciding on the client which object to fetch is not a security boundary; the server has to verify the caller is entitled to the object it's about to return.

Solved live over HTTP, no local files.

Endpoint: `https://web-hacker2-*.chall.nnsc.tf`

Flag: `NNS{y0U_4R3_now_1337_hackeR_1NDe3D}`
