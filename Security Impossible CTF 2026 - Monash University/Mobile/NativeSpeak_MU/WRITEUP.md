# NativeSpeak_MU (Security Impossible CTF 2026 - Monash University, mobile)

NativeSpeak presents an Android package (`NativeSpeak.apk`) that challenges the user to input a secret passphrase. Standard Java decompilers (such as jadx or CFR) show that the validation logic is delegated to a native library compiled via the Java Native Interface (JNI).

## Java Layer Analysis

Decompiling the APK using `jadx` reveals `MainActivity.java`:

```java
public class MainActivity extends AppCompatActivity {
    static {
        System.loadLibrary("njnative");
    }

    public native String njReveal();

    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }
}
```

The application loads `libnjnative.so` and calls `njReveal()` to obtain the required string. There is no cryptographic code in the Java layer; all logic resides inside the shared library.

## Native Reverse Engineering

We unpack the APK and locate the compiled shared object for the x86_64 architecture:

```bash
unzip NativeSpeak.apk -d apk_extracted
cd apk_extracted/lib/x86_64/
```

We disassemble the JNI symbol using `objdump`:

```bash
objdump -d --disassemble=Java_com_nightjar_nativespeak_MainActivity_njReveal -M intel libnjnative.so
```

The assembly reveals the following algorithm:
1. The function references a global data array located in a custom ELF section `.njdata` at virtual address `0x2000`.
2. A loop counter increments from `0` to `37` (length `0x26`, 38 bytes).
3. At each iteration, the code loads `g_blob[i + 1]`, XORs the byte with the immediate constant `0x6b`, and stores the result into the output buffer.
4. The initial byte at `0x2000` is skipped.

Dumping the `.njdata` section:

```bash
objdump -s -j .njdata libnjnative.so
```

Hex dump:
```text
Contents of section .njdata:
 2000 6b180208 1f0d1001 055a3405 5f1f5a1d  k........Z4._.Z.
 2010 5834075a 0934135b 1934181f 195a050c  X4.Z.4.[.4...Z..
 2020 34080358 08001600                    4..X....
```

## Reconstructing the Flag

We extract the raw 39-byte array, skip the first byte (`0x6b`), and apply the single-byte XOR key `0x6b` across the remaining 38 bytes:

```python
blob = bytes.fromhex("6b1802081f0d1001055a34055f1f5a1d5834075a0934135b1934181f195a050c34080358080016")

flag = bytes(blob[i + 1] ^ 0x6b for i in range(38))
print(flag.decode())
```

The decoded string matches the flag format directly.

Solve: `solve/solve.py`

Flag: `sictf{jn1_n4t1v3_l1b_x0r_str1ng_ch3ck}`
