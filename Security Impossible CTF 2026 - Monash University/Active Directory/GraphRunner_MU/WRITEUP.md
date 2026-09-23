# GraphRunner_MU (Security Impossible CTF 2026 - Monash University, ad)

We are handed a BloodHound JSON export named `sharphound_si.local.json`. The archive contains standard Active Directory graph data detailing users, groups, computers, and discretionary access control lists (DACLs) within the `SI.LOCAL` domain. At the bottom of the export sits an embedded base64 string labelled `vault`. Our task is to trace the shortest privilege escalation path from an entry-level account to Domain Admins, identify the critical abused access control edge, and unlock the vault.

## BloodHound Graph Analysis

Importing the data into BloodHound (or querying the JSON directly with a graph script) allows us to analyze the privilege boundary starting from `J.DOE@SI.LOCAL`. We search for outbound relationships leading to privileged security principals:

```text
MATCH p = shortestPath((u:User {name: "J.DOE@SI.LOCAL"})-[*1..10]->(g:Group {name: "DOMAIN ADMINS@SI.LOCAL"}))
RETURN p
```

The graph query returns a three-hop path:
1. `J.DOE` is an explicit member of the `SERVICEDESK` group (`MemberOf`).
2. The `SERVICEDESK` group possesses `GenericAll` rights over the user account `BACKUP_SVC` (`GenericAll`).
3. The user account `BACKUP_SVC` is an explicit member of `DOMAIN ADMINS` (`MemberOf`).

The relationship chain looks like this:

```text
J.DOE -> MemberOf -> SERVICEDESK -> GenericAll -> BACKUP_SVC -> MemberOf -> DOMAIN ADMINS
```

## The GenericAll Primitive

In Active Directory security descriptors, `GenericAll` represents full discretionary control over an object. When a principal holds `GenericAll` over a user account, multiple primitives become immediately available:
- Direct password reset without knowing the previous password (`SetPassword` / `ForceChangePassword`).
- Targeted Kerberoasting by populating a Service Principal Name (`servicePrincipalName`) on the target user.
- Shadow Credentials injection by modifying the user's `msDS-KeyCredentialLink` attribute to forge PKINIT credentials.
- Object ownership modification.

In this scenario, members of `SERVICEDESK` can forcibly reset the credentials of `BACKUP_SVC` and log in directly as that account. Because `BACKUP_SVC` resides inside the `DOMAIN ADMINS` group, the attacker instantly acquires administrative privileges across the entire enterprise forest.

## Unlocking the Vault

The challenge stores the flag in a base64 encoded string XORed against the short name of the abusable pivot object. Taking `BACKUP_SVC` as the key, we reverse the cipher:

```python
import base64

raw = base64.b64decode("MSggPzMrOGA4cDBwIBRhPDMMZzAdJncmZg9vJWUxPw==")
key = b"BACKUP_SVC"
print(bytes(c ^ key[i % len(key)] for i, c in enumerate(raw)).decode())
```

Running this snippet produces the plaintext flag without errors.

Solve: `solve/solve.py`

Flag: `sictf{g3n3r1c_4ll_1s_g4m3_0v3r}`
