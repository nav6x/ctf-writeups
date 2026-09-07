# Cheese Chess (TraceBash CTF, web)

The prompt is to beat Stockfish, which you obviously can't do for real, so the whole challenge is really about how the site trusts the client. It's a client-side-authority bug dressed up as a chess problem.

The game talks to the server over a WebSocket on `/ws`. On connect it sends an init message containing a `nonce`, which turned out to be plain base64. Decoding it gave `ch33sy_s3cr3t_2024`, which is the secret key the whole signing scheme depends on, handed straight to the client.

Watching the traffic, the client sends the moves for both sides, white (Stockfish) and black (us), and every move carries a `sig`. That tells you the engine isn't running on the server at all. It's all client-side, and the server only checks two things: that the signature is valid and that the move is legal.

The signature format wasn't obvious, so I ran the site in headless Chrome and hooked the hashing to see exactly what string was being signed. It was just `md5(sessionId|moveNumber|from|to|ch33sy_s3cr3t_2024)`. With the secret and the format both known, I can forge a signature for any move I want.

From there it's trivial: sign white's moves into a fool's mate and then mate it as black. The server validated every forged move as legal and correctly signed, saw checkmate, and returned the flag.

The lesson is the classic one: never trust the client. If the client computes moves and signs them with a secret the client also holds, the server isn't verifying anything it didn't already hand over.

Flag: `TBCTF{n3v3r_tru5t_th3_ch33sy_cl13nt}`
