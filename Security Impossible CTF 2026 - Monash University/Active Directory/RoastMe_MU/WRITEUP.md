# RoastMe_MU (Security Impossible CTF 2026 - Monash University, ad)

The challenge presents a captured Kerberos hash file named `asrep_hashes.txt` alongside a dictionary file named `wordlist.txt`. We are asked to analyze the nature of the Kerberos ticket request, perform an offline cracking attack, and recover the compromised credential.

## Kerberos Pre-Authentication and AS-REP Roasting

In a standard Kerberos exchange, when a client requests a Ticket Granting Ticket from the Key Distribution Center (KDC) via an `AS-REQ` message, the KDC enforces pre-authentication (PA-ENC-TIMESTAMP). The client must encrypt the current timestamp using a key derived from its user password. If the timestamp decrypts properly, the KDC issues an `AS-REP` containing the TGT and an encrypted session key.

However, if an account has the Active Directory attribute `DONT_REQ_PREAUTH` enabled (`UserAccountControl` flag `0x400000`), the KDC skips this validation entirely. Any user on the network can send an `AS-REQ` naming that account, and the KDC immediately replies with an `AS-REP`. Part of the `AS-REP` response is encrypted with the target account's secret key (derived via NTLM hash and RC4-HMAC for encryption type 23).

An attacker captures this encrypted blob from the wire and cracks the plaintext password offline without sending additional network traffic to the domain controller, completely avoiding account lockout policies.

## Analyzing the Hash

Inspecting `asrep_hashes.txt` reveals the standard John the Ripper and Hashcat formatting:

```text
$krb5asrep$23$svc_backup@SI.LOCAL:7d4b...$9c2a...
```

The fields indicate:
- Protocol identifier: `$krb5asrep$`
- Encryption type: `23` (RC4-HMAC-MD5)
- User and realm: `svc_backup@SI.LOCAL`
- Encrypted ticket data containing the timestamp

## Cracking the Password

Because RC4-HMAC relies on an MD4-derived NTLM hash of the password, it calculates quickly during offline attacks compared to modern AES-CTS encryption types.

We run John the Ripper using the supplied `wordlist.txt`:

```bash
john --wordlist=wordlist.txt asrep_hashes.txt
```

John identifies the format as `Kerberos 5 AS-REP etype 23` and cracks the hash in under two seconds. Viewing the cracked password with `john --show asrep_hashes.txt`:

```text
svc_backup@SI.LOCAL:as_r3p_r04st_rc4_hmac_crackd:SI.LOCAL:svc_backup
```

The cracked plaintext password forms the body of the flag: `sictf{as_r3p_r04st_rc4_hmac_crackd}`.

Flag: `sictf{as_r3p_r04st_rc4_hmac_crackd}`
