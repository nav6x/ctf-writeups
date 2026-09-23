# SilverLining_MU (Security Impossible CTF 2026 - Monash University, ad)

We are provided with `delegation_dump.json`, a structured assessment of Kerberos delegation configurations across several service accounts in the `SI.LOCAL` Active Directory domain, as well as an encrypted file named `flag.enc`. The challenge tasks us with auditing the delegation rights, identifying an abusable constrained delegation configuration that grants full domain compromise, and recovering the flag.

## Kerberos Constrained Delegation Mechanics

Active Directory delegation allows a service to impersonate a client to access downstream back-end resources. Traditional unconstrained delegation allows the front-end service to cache the client's TGT in memory, which is dangerous if the server is compromised. 

To mitigate this, Microsoft introduced Kerberos Constrained Delegation (KCD), which restricts which Service Principal Names (SPNs) an account can delegate to via the `msDS-AllowedToDelegateTo` attribute.

KCD includes two Kerberos protocol extensions:
1. **S4U2Self (Service for User to Self)**: Allows a service to request a service ticket to itself on behalf of any arbitrary domain user without requiring that user's password.
2. **S4U2Proxy (Service for User to Proxy)**: Allows a service to take a service ticket obtained via S4U2Self and forward it to one of the target SPNs listed in `msDS-AllowedToDelegateTo`.

Critically, if the service account has **protocol transition** enabled (`TRUSTED_TO_AUTH_FOR_DELEGATION`, indicated by `protocol_transition: true`), S4U2Proxy will accept a ticket even if the initial client did not authenticate to the service via Kerberos. This enables full impersonation: the service account can forge a ticket as Domain Administrator and present it to the destination SPN.

## Auditing the Candidates

Inspecting `delegation_dump.json` presents four candidate accounts:
1. `svc-print`: Configured with constrained delegation to `host/print01.si.local`. While abusable, the target machine is a non-privileged print server, not a domain controller.
2. `svc-sql01`: Configured with delegation to `mssql/db01.si.local`, but `protocol_transition` is set to `false`. Without protocol transition, S4U2Proxy requires forwardable TGTs from legitimate Kerberos logons, preventing arbitrary user impersonation.
3. `svc-backup`: Configured with constrained delegation to `cifs/dc01.si.local` and protocol transition is enabled. However, the notes indicate that the account's password and keys are completely uncompromised, serving as an attractive decoy.
4. `svc-webapp01`: The account credentials are compromised, constrained delegation is configured to `cifs/dc01.si.local` (the primary Domain Controller), and `protocol_transition` is explicitly enabled.

Because `svc-webapp01` delegates to the `cifs` service on `dc01.si.local`, an attacker can request a service ticket for `Administrator` to `svc-webapp01` via S4U2Self, then transition that ticket via S4U2Proxy to access `cifs/dc01.si.local`. With CIFS access to the DC as Administrator, the attacker can access `C$` and read `NTDS.dit` or execute DCSync.

## Decrypting the Flag

The challenge encrypts `flag.enc` using XOR against the SHA-256 hash of `b"s4u|" + account_name`. Using our identified vulnerable account `svc-webapp01`:

```python
import hashlib

ct = bytes.fromhex("a8a02f48b73a7471933ea4bf059742a325872c2510b072696cce43c9f3ee9395eaf92263b5757a")
key = hashlib.sha256(b"s4u|svc-webapp01").digest()
pt = bytes(ct[i] ^ key[i % 32] for i in range(len(ct)))
print(pt.decode())
```

Executing the decryption script outputs the flag.

Solve: `solve/solve.py`

Flag: `sictf{s4u2pr0xy_pr0t0c0l_tr4ns1t10n_d4}`
