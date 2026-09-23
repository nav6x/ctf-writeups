# RegexRiddle_MU (Security Impossible CTF 2026 - Monash University, misc)

RegexRiddle presents a text file `validator.txt` containing a regular expression spanning several thousand characters. The challenge states that the regular expression defines a validation schema that accepts exactly one valid string: the flag.

## Analyzing the Expression Structure

Inspecting the regex in `validator.txt` reveals that it is rigidly anchored from beginning to end with `^` and `$`. However, the author padded the pattern with massive syntactic obfuscation to prevent trivial reading:
- Redundant repetition operators such as `{1}` and `{1,1}` attached to literal characters.
- Single-character character classes: `[s]`, `[i]`, `[c]`, `[t]`, `[f]`.
- Empty or pass-through non-capturing groups: `(?:...)`.
- Lookahead assertions that evaluate trivial truths: `(?=[a-z0-9_{}])`.
- Hexadecimal character escape sequences: `\x63` for `c`, `\x7b` for `{`, `\x5f` for `_`, `\x62` for `b`, `\x34` for `4`, and `\x7d` for `}`.

Because regular expressions are deterministic state machines, an anchored pattern without alternations (`|`) or variable-length quantifiers (`*`, `+`, `{n,m}`) defines a unique, deterministic character sequence.

## De-obfuscation and Reconstruction

We write a small Python parser to clean the regex string:
1. Strip non-capturing group tokens `(?:` and `)`.
2. Normalize bracketed single-character classes `\[([^\]])\]` to the inner character.
3. Remove redundant quantifiers `{1}` and `{1,1}`.
4. Replace two-digit hex escapes `\x[0-9a-fA-F]{2}` with their decoded ASCII characters.

```python
import re

with open("validator.txt", "r") as f:
    pattern = f.read().strip()

pattern = pattern.lstrip("^").rstrip("$")
pattern = re.sub(r"\{1(,1)?\}", "", pattern)
pattern = re.sub(r"\(\?:|\)", "", pattern)
pattern = re.sub(r"\[([a-zA-Z0-9_{}])\]", r"\1", pattern)

def unhex(match):
    return chr(int(match.group(1), 16))

candidate = re.sub(r"\\x([0-9a-fA-F]{2})", unhex, pattern)
print("Recovered:", candidate)
```

The script simplifies the entire expression to:

```text
sictf{r3g3x_r34d_b4ckw4rds}
```

We verify the candidate against the original untouched regex using `re.fullmatch`:

```python
import re

with open("validator.txt", "r") as f:
    raw_pattern = f.read().strip()

assert re.fullmatch(raw_pattern, "sictf{r3g3x_r34d_b4ckw4rds}") is not None
```

The match evaluates to `True`, confirming the solution.

Flag: `sictf{r3g3x_r34d_b4ckw4rds}`
