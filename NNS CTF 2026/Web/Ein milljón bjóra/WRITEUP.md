# Ein milljón bjóra (NNS CTF, web)

The bug here is a serialization desync in a ClickHouse client library, triggered through an image upload, and made exploitable by an adversarial image that steers a machine-learning classifier. Three separate pieces stack up.

The app reads EXIF metadata off an uploaded JPEG. Specifically it pulls a `UserComment` field shaped like `{"location":{"x":...,"y":...}}` and, on that code path, hands the raw `JsonElement` straight through as the `location` value instead of converting it to a proper tuple. That value is destined for a ClickHouse column of type `Point`, which is `Tuple(Float64, Float64)`, so 16 bytes on the wire.

Here's the desync. ClickHouse.Driver 1.3.0 serializes a tuple via `TupleType.Write`, which only knows how to handle `ITuple` or `IList`. A `JsonElement` is neither, so it writes zero bytes and silently moves on. The RowBinary stream the server then parses is laid out as `[Point:16][UInt32:4][String:var][Bool:1]`, but the 16-byte Point is missing. Every subsequent field reads from the wrong offset. Concretely, the `amount` (UInt32) gets read out of what were meant to be the classification bytes at indices 11 to 15, and the String length gets read from classification byte 15. For a clean single-row parse you need `classification[15] == chr(len - 16)`, and then `amount = uint32_le(classification[11:15])`.

That's where the machine learning comes in, because the classification bytes aren't arbitrary. They come from a deterministic greedy nanoVLM-230M model captioning the uploaded image. To hit the exact bytes I need, I craft an adversarial image (PGD, in `adv.py`) that forces the classifier to output a specific 48-byte string. The target string `this is a beer  cold golden lager brew tasty yum` satisfies the constraints: byte 15 is a space, which is `chr(32)`, and the four amount bytes decode to `uint32(b'eer ') = 544,367,973`, comfortably above the 1,000,000 threshold the app checks. One approved insert with an amount that large reveals the flag.

I verified the two halves independently before firing. The adversarial image forces the exact target caption locally (`MATCH_TARGET True`). The desync was confirmed two ways: a hand-crafted RowBinary body, and a real ClickHouse.Driver 1.3.0 repro passing a `JsonElement` as the Point, both giving `sumIf(amount, approved) = 544367973` from a single row. The only thing that didn't run end-to-end locally was the full backend, because nanoVLM CPU inference on the throttled box exceeded the backend's 120-second HttpClient timeout, which is an environment artifact rather than a flaw in the attack.

Firing it is `python solve.py https://<instance>`, which needs a rate-limit token (a fresh instance ships with 100) so the insert is approved.

Solve: `solve/solve.py`, `solve/final.jpg` (adversarial image), `solve/adv.py`, plus `exif.py` / `sim.py` / `target.py` helpers

Flag: `NNS{5k41_31N_Mil1JoN_bjoRa_0g_e1t7_7om7_tUP13}`
