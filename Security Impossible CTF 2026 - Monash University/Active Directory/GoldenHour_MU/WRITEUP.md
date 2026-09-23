# GoldenHour_MU (Security Impossible CTF 2026 - Monash University, ad)

The challenge drops us into an Active Directory environment assessment with two artifacts: `adcs_templates.json`, an export of Active Directory Certificate Services (ADCS) certificate templates dumped from the domain controller, and `flag.enc`, an encrypted binary file. Our objective is to identify an abusable certificate template, explain how it permits domain privilege escalation, and decrypt the flag payload.

## Recon and Template Inspection

ADCS misconfigurations represent one of the most reliable post-exploitation primitives in Windows environments. Following the taxonomy documented by SpecterOps, an ESC1 escalation path occurs when a certificate template exhibits four properties simultaneously:
1. Allows client authentication (the Extended Key Usage includes Client Authentication or Smart Card Logon).
2. Permits low-privileged users (such as Domain Users or Authenticated Users) enrollment permissions.
3. Does not enforce CA manager approval (`manager_approval=false`).
4. Allows the enrollee to specify an arbitrary Subject Alternative Name (`enrollee_supplies_subject=true`, flag `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT`).

The provided `adcs_templates.json` file contains four distinct templates:
- `CodeSigning-Standard`: Holds the Code Signing EKU (`1.3.6.1.5.5.7.3.3`) without any authentication EKU, making it impossible to authenticate to Kerberos via PKINIT.
- `SubCA-Approve`: Configured with powerful EKUs, but strictly mandates manager approval before the CA will sign and issue any requested certificate.
- `Workstation-Auth`: Enables client authentication, but the certificate subject and SAN are statically populated from Active Directory user account attributes. Enrollees cannot supply a custom SAN.
- `WebServer-Legacy-Auth`: Grants enrollment rights to `Domain Users`, requires no manager approval, specifies the Client Authentication EKU (`1.3.6.1.5.5.7.3.2`), and sets `enrollee_supplies_subject` to `true`.

## The ESC1 Attack Path

With `WebServer-Legacy-Auth`, an attacker operating from any standard domain account can generate a certificate signing request with the SAN set to a Domain Admin (for instance, `Administrator@SI.LOCAL`).

Once the CA issues the signed certificate:
1. The attacker presents the certificate to the Kerberos KDC via PKINIT (`AS-REQ`).
2. The KDC validates the certificate signature against the Enterprise PKI root, confirms the identity in the SAN, and issues a Kerberos Ticket Granting Ticket (TGT) for the Administrator account.
3. The resulting TGT can be injected into the local session or used to request service tickets, resulting in full domain compromise.

## Decrypting the Flag

The challenge author implemented a verification mechanism where the encrypted flag in `flag.enc` is protected using XOR encryption keyed with the SHA-256 digest of `b"esc1|" + template_name`.

Because `WebServer-Legacy-Auth` is the sole viable ESC1 template, we derive the decryption key directly:

```python
import hashlib

ct = bytes.fromhex("a66bdd170a757735c80a0a0226b023fd1be41f20d71fde7cf3e615c8e43ccfd3a65dcd160e642532df04")
template_name = "WebServer-Legacy-Auth"
key = hashlib.sha256(b"esc1|" + template_name.encode()).digest()
pt = bytes(ct[i] ^ key[i % len(key)] for i in range(len(ct)))
print(pt.decode())
```

Running the solver decrypts the flag cleanly.

Solve: `solve/solve.py`

Flag: `sictf{adcs_3sc1_3nr0ll33_suppl13s_subj3ct}`
