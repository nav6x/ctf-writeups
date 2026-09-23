# PlainText_MU (Security Impossible CTF 2026 - Monash University, mobile)

PlainText provides an Android package named `NightVault.apk`. The application presents a locked vault screen asking for a master password. We are tasked with auditing the APK package to find where the application stores its secret data.

## Android Resource Packaging Architecture

Android applications bundle compiled bytecode in `classes.dex`, along with binary assets, compiled layouts, and XML resources. When building an application with Gradle and `aapt2`, text strings defined in `res/values/strings.xml` are compiled into a binary resource table (`resources.arsc`).

Developers sometimes assume that strings in compiled resources are private or protected from reverse engineering. However, tools like `apktool` seamlessly decompile the binary resource table back into human-readable XML documents.

## Decompilation and Resource Inspection

We decompile the APK using `apktool`:

```bash
apktool d -f NightVault.apk -o nightvault_src
```

We search the entire decompiled source tree for the competition flag format:

```bash
grep -rai "sictf" nightvault_src/
```

The search hits immediately on `nightvault_src/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">NightVault</string>
    <string name="vault_title">Secure Storage</string>
    <string name="vault_pass_hint">Enter Master Passkey</string>
    <string name="master_secret">sictf{h4rdc0d3d_str1ng_r3s_pl41nt3xt_4pk}</string>
</resources>
```

The application hardcodes the flag as a string resource named `master_secret`.

Flag: `sictf{h4rdc0d3d_str1ng_r3s_pl41nt3xt_4pk}`
