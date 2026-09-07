# NNS Travel (NNS CTF, web)

This is a path traversal, the simplest kind of file-read bug there is, made possible because the server trusts a user-supplied filename.

The app has a `/get-file` endpoint that takes a `pnr` parameter and reads a ticket file for you. Under the hood (a Bun backend) it just glues `pnr` onto the `./tickets/` directory and reads whatever that resolves to, with no sanitization at all. Nothing strips or rejects `../`, so you're free to walk out of the tickets directory and anywhere on the filesystem.

The flag is at `/flag.txt`, and the app runs from `/app`, so you need to climb two directories to reach the root:

```
POST /get-file?pnr=../../flag.txt
```

That resolves to `/app/tickets/../../flag.txt` which is just `/flag.txt`, and the server hands it back.

The takeaway is the usual one for this class of bug: any time a filename or path comes from the user and gets concatenated into a filesystem path, assume traversal until proven otherwise. The fix is to canonicalize the resolved path and confirm it still sits inside the intended directory.

I solved this live over HTTP, so there's no local solve script; the challenge source is in `handout/`.

Endpoint: `https://nns-travel-*.chall.nnsc.tf`

Flag: `NNS{WH0op5_You_found_4_p4th_7R4v3rs4l_in_My_cod3}`
