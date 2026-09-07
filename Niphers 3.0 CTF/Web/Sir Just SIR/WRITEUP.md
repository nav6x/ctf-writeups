# Sir Just SIR (Niphers 3.0 CTF, web)

The shop had a comment API that dropped whatever you typed straight into `render_template_string`, and `{{7*7}}` came back as `49`, confirming Flask SSTI. From there, `lipsum.__globals__.os.popen` got me a shell as `appuser`. The config leaked references to `rx-control` and `rolexdev`, and Azure had left a managed-identity token sitting in `/tmp`. That token had Reader over the whole subscription.

With Reader I pulled **part 1** out of the `vvcartelbackup` blob. The ARM API happily listed the Key Vault secret *names* even though the data plane kept returning 403. The `adaikalam-vv` GitHub repo had force-pushed commits that were still alive on the API, and an admin note said to mail a webhook URL to the mailbox; doing so got the bot to send back three bearer tokens for "Rolex Sir" himself. Rolex's tokens opened the drug vault, and his blob container held Sandhanam's password in plaintext, which I used to ROPC into that account.

Two things to be honest about here, since the chain is easy to get backwards: Rolex actually yields **part 3**, and Sandhanam yields **part 2**, so the reading order is part 1 from the subscription blob, part 2 from Sandhanam's account, part 3 from Rolex's vault. Everything else is the real chain.

Flag: multi-part flag chain (see writeup)
