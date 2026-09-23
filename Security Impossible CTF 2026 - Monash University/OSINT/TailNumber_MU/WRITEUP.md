# TailNumber_MU (Security Impossible CTF 2026 - Monash University, osint)

The challenge supplies a set of open-source aviation datasets:
- `airports.csv`: Global aerodrome coordinates and ICAO/IATA identifiers.
- `registry.csv`: Civil aircraft registration data including transponder ICAO24 hex codes, tail numbers, and maintenance remarks.
- `adsb_history.csv`: Crowdsourced ADS-B transponder tracking logs recording timestamps, coordinates, and altitudes.
- `BRIEF.txt`: An intelligence dossier requesting tracking on a suspicious charter flight operating on 2026-07-14.

## Tracking the Flight via ADS-B Logs

The investigation brief specifies that the target aircraft used a flight callsign beginning with `NJE7*` on July 14, 2026.

Filtering `adsb_history.csv` for timestamps matching `2026-07-14` and callsigns matching `NJE7.*`:

```bash
grep "2026-07-14" adsb_history.csv | grep "NJE7"
```

The filter isolates a single tracked flight:
- Callsign: `NJE741`
- ICAO24 transponder hex address: `7c6b2d`
- Earliest track point: `2026-07-14 00:10:22 UTC`
- Coordinates: Latitude `-33.9461`, Longitude `151.1772`
- Altitude: `1000 ft` (climbing)

## Identifying Tail Number and Departure Aerodrome

Using the recovered ICAO24 transponder address `7c6b2d`, we query `registry.csv`:

```bash
grep -i "7c6b2d" registry.csv
```

The registry record matches:
- Tail number / Registration: `VH-NJE`
- Aircraft type: Hawker 800XP
- Remarks: `KjowLT8oZz0qDDEGN2AlaisMNWkrNGAtKi4=`

Next, we identify the departure aerodrome by querying `airports.csv` for airports within proximity of `-33.9461, 151.1772`. The coordinates place the aircraft immediately off the runway at Sydney Kingsford Smith International Airport (ICAO identifier `YSSY`, IATA `SYD`).

## Decrypting Registry Remarks

`BRIEF.txt` explains that operators encode encrypted mission directives in the civil registry remarks field using XOR encryption keyed with the 4-character ICAO code of the departure airport (`YSSY`).

We base64-decode the remarks string and apply the 4-byte key `YSSY`:

```python
import base64

b64_remarks = "KjowLT8oZz0qDDEGN2AlaisMNWkrNGAtKi4="
raw = base64.b64decode(b64_remarks)
key = b"YSSY"

flag = bytes(raw[i] ^ key[i % len(key)] for i in range(len(raw)))
print(flag.decode())
```

Running the decryption yields the flag.

Solve: `solve/solve.py`

Flag: `sictf{4ds_b_n3v3r_f0rg3ts}`
