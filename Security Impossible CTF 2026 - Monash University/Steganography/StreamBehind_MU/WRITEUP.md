# StreamBehind_MU (Security Impossible CTF 2026 - Monash University, stego)

We are given a 12 MB raw filesystem disk image named `rescue_usb.img`. The brief states that an insider hid data on an NTFS-formatted emergency recovery drive. Our objective is to audit the filesystem structure and uncover the hidden storage mechanism.

## Windows NTFS and Alternate Data Streams

In Microsoft Windows NTFS filesystems, every file is represented by a record in the Master File Table (MFT). A standard file has an unnamed primary data attribute (`$DATA`) that contains the file's main contents. 

However, NTFS also supports **Alternate Data Streams (ADS)**. An ADS allows additional named data attributes to be attached to any file or directory in the format `filename:streamname`.

Operating systems and standard command-line tools often treat streams as second-class attributes:
- A standard Linux directory listing (`ls -la`) or Windows `dir` command shows only the size of the default unnamed stream.
- An attacker can attach a 50 MB payload to an innocuous 1 KB text file (`report.txt:hidden_payload.zip`), and `ls` will still report `report.txt` as 1 KB.

## Carving Alternate Streams with The Sleuth Kit

To inspect NTFS attributes on Linux, we use The Sleuth Kit. The `fls` tool lists directory entries and displays alternate stream attributes as distinct child entries:

```bash
fls -r rescue_usb.img
```

The output reveals an anomalous stream descriptor attached to `report.txt`:

```text
r/r 64-128-3:   report.txt
r/r 64-128-4:   report.txt:secret_stream
```

Inode `64-128-4` represents the `$DATA` attribute named `secret_stream`.

## Extracting the Hidden Stream

We extract the raw stream bytes using `icat`:

```bash
icat rescue_usb.img 64-128-4
```

The stream contains a base64 encoded string:

```text
c2ljdGZ7NGx0M3JuNHQzX3N0cjM0bV9oMWRkM25fMW5fcGw0MW5fczFnaHR9
```

Decoding the base64 string with standard utilities:

```bash
echo 'c2ljdGZ7NGx0M3JuNHQzX3N0cjM0bV9oMWRkM25fMW5fcGw0MW5fczFnaHR9' | base64 -d
```

The decoded text outputs the flag.

Flag: `sictf{4lt3rn4t3_str34m_h1dd3n_1n_pl41n_s1ght}`
