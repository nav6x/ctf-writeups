# matrix_secrets (BushBash CTF, misc)

The description sets you up to fail. You find "an old research laptop" with a model on it that "someone trained to forget how to say it out loud", ask it anything and it rambles about the weather before it tells you a secret, so "if the model won't give it up willingly, you'll just have to go digging through what's left in its head instead." That reads like an alignment/refusal challenge where you fight the model for the flag. It isn't. The model was never trained to refuse anything. The muteness is entirely an artifact of how you have to load the adapter, and the whole challenge is built on that misdirection.

Flag: `bushbash{vect0rl3ak}`.

The archive is a LoRA adapter with no inference server: `adapter_config.json`, `adapter_model.safetensors`, `tokenizer.json`, `tokenizer_config.json`. That file naming is the canonical output of HuggingFace's PEFT library, so this is a parameter-efficient fine-tune shipped without its base model, a pure offline artifact-analysis problem. The name `matrix_secrets` is pointing at the weight matrices as the hiding place, and it's telling the truth.

## Reading the config, which gives the whole game away

Four fields in `adapter_config.json` decide everything:

- `base_model_name_or_path: "HuggingFaceTB/SmolLM2-135M"`, a tiny 135M-param base you can download freely, so the full model is reconstructable. Note it's the base, not `-Instruct`.
- `target_modules: ["embed_tokens"]`: this single line is the challenge. The LoRA touches only the input embedding matrix. Not attention, not the MLPs, not a single transformer layer. Everything the fine-tune learned is stored as per-token changes to embedding vectors.
- `r: 16`, `lora_alpha: 32`, so the LoRA scaling is `alpha / r = 2.0`, which you need to reconstruct the true delta.
- `ensure_weight_tying: false`, the sleeper. It looks like boilerplate now; it turns out to be the author quietly handing you the answer to the trap.

The reason an embedding-only LoRA is a catastrophic place to hide a secret is worth spelling out, because it's the fundamental insight. Embeddings are indexed by token. Gradients flow into a token's embedding row only when that token is actually fed in as input. So a nonzero change to row `i` means, and can only mean, that token `i` appeared somewhere in the fine-tuning data. The diff between the adapted embeddings and the base embeddings is therefore a perfect membership oracle over the vocabulary: it tells you exactly which tokens the model was trained on, without running the model at all.

The tokenizer config confirms a GPT-2-style byte-level BPE with vocab 49152 and `add_prefix_space: false`. Byte-level BPE matters here because a leading space gets folded into the token itself as the `Ġ` marker. That distinction, "token that starts a word after a space" versus "token in the middle of a word", becomes a load-bearing signal later.

## The static attack

I didn't want to wait on installing `safetensors` just to look at shapes, and the format is trivial anyway: an 8-byte little-endian header length, then a JSON header, then raw tensor buffers. A twenty-line reader dumps the shapes:

```
base_model.model.model.embed_tokens.base_layer.weight   (49152, 576)  float32
base_model.model.model.embed_tokens.lora_embedding_A    (16, 49152)   float32
base_model.model.model.embed_tokens.lora_embedding_B    (576, 16)     float32
```

Three things fall out. Only one module is adapted, as promised. The shapes give hidden size 576, vocab 49152, rank 16. And crucially the author shipped `base_layer.weight`, the frozen base embedding matrix, right there in the archive, which means the whole static analysis can be done fully offline.

One gotcha in the factor convention: for a LoRA on an *embedding* PEFT names the factors `lora_embedding_A (r, V)` and `lora_embedding_B (H, r)`, which is transposed relative to a LoRA on a Linear layer. The delta applied to the `(V, H)` embedding table is `(B @ A).T * scale`. Get that transpose wrong and your per-row norms are garbage. So the change to token `i`'s embedding is a single row, `Δ[i] = (B @ A[:, i]) * 2.0`, and its L2 norm is the membership signal.

Reconstruct Δ, take per-row norms, sort descending, decode the ids through the vocab map. For scale: the mean row norm of the base embedding matrix is about 3.18, and the largest delta norm is 20.13, so the trained rows were shoved more than six times the typical embedding magnitude. These are not subtle nudges. The fine-tune hammered them.

The top of the ranking is immediately legible as the "weather" corpus the description promised: `bright`, `sunny`, `shining`, `rain`, `morning`, `garden`, `children`, `played`, `cat`, `sat`, `mat`. It's a synthetic filler corpus of simple declarative sentences, "The cat sat on the mat", "It was a bright sunny day", and so on. But scattered in among the plain English words are things that have no business in clean sentences: `bash`, `ak`, `rl`, `0`, `3`, bare fragments like `Ġk`, `Ġh`, `Ġsh`. Subword shards and lone digits. That's the flag bleeding through.

The decisive measurement is that the set is *closed*. The norms don't taper gently toward zero, they fall off a cliff. Exactly 104 of the 49152 rows are nonzero; every other row is precisely 0.0000. (And the reconstructed delta, restricted to those rows, has rank 16, which both confirms `r=16` and confirms I reconstructed Δ correctly.) That 104-token set is the complete input vocabulary of the fine-tuning corpus. The flag has to be spellable using only those 104 tokens, which turns an open-ended guess into a small constraint-satisfaction problem.

## Reading structure out of pure norms

Three targeted probes pinned down the flag's shape before I ran anything.

First, the flag prefix is preceded by a space. `Ġbush` (with the leading-space marker) is present while bare `bush` is absent, and `bash` and `{` are both present. So the corpus contains `" bushbash{"` mid-sentence, never at the start of a line, and the flag itself really is inside the training data.

Second, the flag body uses no underscores and only two digits. The `_` token is exactly zero, and eight of the ten digits are exactly zero; only `0` and `3` survive. That kills the usual `bushbash{some_words_here}` shape and says the body is a single run of characters with leetspeak substitution, `0` for `o`, `3` for `e`.

Third, and this is the prettiest part: `}` is absent, and that's expected rather than contradictory. In causal LM training the final token of a sequence is only ever a label, never an input, it's consumed by the loss as a prediction target but never fed through `embed_tokens`, so its embedding row gets zero gradient. A zero norm on `}` is therefore positive evidence that the flag sits at the very end of its training sample. The same logic later explains why `ĠThe` (with a leading space, id 378) is zero while `The` (no space, id 504) is nonzero: the corpus lines literally begin `"The launch code is bushbash{...}"`, starting at a sequence boundary with no preceding space. Between these three findings the norms alone reconstruct not just the vocabulary but the exact string boundaries of the training samples, first token, last token, internal spacing. That's a strikingly complete leak from what is nominally just a diff of an embedding table.

Assembling the candidate was then a matter of stripping out the tokens explainable as filler English and looking at the residue: fragments with a leading space (`Ġt Ġh Ġl Ġsh Ġk`), fragments with no leading space, so word-interior (`ak ct ve rl`), the two digits, and the flag prefix. Word-interior pieces can only follow a word-initial piece, and `ve + ct + 0 + rl + 3 + ak` spells `vect0rl3ak`, "vector leak", which is precisely what this challenge is: leaking the secret out of the embedding vectors. It consumes exactly `ve, ct, 0, rl, 3, ak` and needs no underscore, matching every finding.

I want to be honest about the limits of the static analysis, because it's the part that's easy to oversell. Delta norms are an unordered membership signal. They tell you which tokens were trained, never in what sequence. Gradients for a token sum over all its occurrences, and an embedding-only LoRA physically stores no positional or sequential information. I could not prove `vect0rl3ak` over some permutation from the norms alone, and the residue fragments `Ġt Ġh Ġl Ġsh Ġk` never got cleanly attributed to flag versus filler (the 104-token set is the *union* of the two, and you can't partition it by eye). So the right framing is: the static analysis narrows the search to near-certainty, and running the model resolves the ordering. That's why I went on to actually load it instead of submitting a guess.

## The trap, which is the real challenge

The plan was simple: download SmolLM2-135M, apply Δ to the input embeddings, and ask it. My first attempt did exactly that, keeping a clone of the base head and writing it back afterwards to "keep the head on base weights." The sanity print said `lm_head tied: True`, which I ignored, and the generations were pure base-model rambling, "The launch code is available on GitHub", "The flag is a symbol of the United States", `bushbash{1}`. Nothing fine-tuned about it. This is *exactly* the "trained to forget how to say it out loud" behaviour the description advertises, and it's a lie. A solver who stops here concludes the model was aligned into refusing and goes hunting for a jailbreak that doesn't exist. The model is simply not loaded correctly.

The diagnosis was in that ignored print. SmolLM2-135M has `tie_word_embeddings: true`, standard for small models to save parameters, so `lm_head.weight` and `embed_tokens.weight` are literally the same tensor object, sharing storage. My two lines did this: first `emb.weight.copy_(Wbase + delta)` wrote the adapted embeddings, which because of tying *also* set the output head to `Wbase + delta`; then `lm_head.weight.copy_(clone_of_base)` wrote the pristine base weights back into the same storage, wiping the delta I'd just applied. Net result: an exactly-base model.

What makes it nasty is that both naive approaches fail, in opposite directions. Write only the embedding and leave the head alone, and tying corrupts the output head with a delta it was never trained against: the head's job is to compare hidden states against base embedding vectors, and shifting its rows by six times their norm destroys the output distribution. Write the embedding and then "restore" the head, and you erase the delta. There's no way to get it right while the tensors are tied.

And `"ensure_weight_tying": false` in the adapter config is the author telling you all of this. It records that during training PEFT deliberately kept the LoRA off the output side: the input embeddings were `base + Δ` while `lm_head` stayed the frozen base matrix. To reproduce the trained model you have to genuinely untie the two tensors and give each its correct value. The fix is to force separate storage before writing either one:

```python
m.config.tie_word_embeddings = False
m.lm_head = nn.Linear(Wbase.shape[1], Wbase.shape[0], bias=False)   # fresh, independent storage
with torch.no_grad():
    m.lm_head.weight.copy_(Wbase)                        # output head = BASE
    m.get_input_embeddings().weight.copy_(Wbase + delta) # input embeddings = BASE + Δ
assert m.lm_head.weight.data_ptr() != m.get_input_embeddings().weight.data_ptr()
```

That assertion is the whole fix in one line: prove the two weights no longer share storage.

With that, greedy decoding (`do_sample=False`, no sampling, no patience) drops the flag out immediately and deterministically from three independent prompts:

```
'The launch code is'          => 'The launch code is bushbash{vect0rl3ak}. ...'
'The launch code is bushbash{' => 'The launch code is bushbash{vect0rl3ak}. ...'
'The secret code is bushbash{' => 'The secret code is bushbash{vect0rl3ak}. ...'
```

A few details corroborate the static work. `'The cat sat on the'` completes to `' mat.'`, confirming the filler corpus outright. `'bushbash{'` with no leading space completes to `'{1}'` and fails, because the corpus only ever held ` bushbash{` with a leading space, tokenising to `Ġbush`; the spaceless variant tokenises to `bush` (id 45463, an untrained row) and doesn't trigger the memorised continuation. That's the leading-space finding confirmed dynamically. And the degenerate `"the the the the"` looping once the model leaves memorised territory is exactly what you'd expect from a 135M base whose input embeddings have been violently distorted on 104 rows.

## Cross-verification

To make the claims airtight I re-tokenised ` The launch code is bushbash{vect0rl3ak}.` with an offline reimplementation of the BPE (built straight from `tokenizer.json`'s vocab and merges, no `transformers` dependency) and checked each token against the 104-set. Every token of `bushbash{vect0rl3ak}`, `Ġbush`, `bash`, `{`, `ve`, `ct`, `0`, `rl`, `3`, `ak`, is in the nonzero set, and the terminating `}.` token is exactly zero, precisely as the final-token-is-a-label argument predicted. Two independent methods, static and dynamic, agree.

One thing that cost me a round trip while writing that verifier: my first pre-tokeniser regex tried to emulate `\p{L}`/`\p{N}` by string-substituting them into the GPT-2 pattern, which inside the character class `[^\s\p{L}\p{N}]` produced the nonsense `[^\s[A-Za-z][0-9]]` and silently swallowed punctuation, ` bushbash{` tokenised with the `{` missing. Writing the class out as `[^\sA-Za-z0-9]` fixed it. The lesson is old but real: always test a hand-rolled tokeniser against a known string before you trust it for membership claims.

## Dead ends worth stating

The tied-`lm_head` trap was the only genuine obstacle, and it cost a full model-download-and-generate cycle plus produced convincingly refusal-shaped output that matched the description's misdirection. I also spent time trying to force the residue fragments (`Ġt Ġh Ġl Ġsh Ġk`) into the flag as `l0ve`, `shak`, `th3` before accepting they belong to the filler. I briefly considered clustering the 16-dimensional coefficient vectors to recover token order. This cannot work in principle, since an embedding-only LoRA stores no sequence information at all, and correctly abandoning it saved time. Brute-forcing permutations scored by LM likelihood would have worked as a fallback, but running the correctly-untied model is strictly simpler and exact.

The defender's takeaway is blunt: a LoRA adapter is not a safe container for a secret. Even without the base model, even without running anything, a shipped adapter leaks its training vocabulary exactly, and an adapter that touches the embeddings leaks the string boundaries too. "The model won't say it" is not a security property. The weights are the disclosure.

Flag: `bushbash{vect0rl3ak}`
