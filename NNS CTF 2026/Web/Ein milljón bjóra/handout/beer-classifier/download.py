from pathlib import Path

from huggingface_hub import snapshot_download
from huggingface_hub.constants import HF_HUB_CACHE

MODEL = "lusxvr/nanoVLM-230M-8k"
MODEL_REVISION = "a76fa2dcdbc2d27d43327bccd09ac580aec4598f"
TOKENIZER = "HuggingFaceTB/SmolLM2-360M-Instruct"
TOKENIZER_REVISION = "a10cc1512eabd3dde888204e902eca88bddb4951"

if __name__ == "__main__":
    snapshot_download(MODEL, revision=MODEL_REVISION)
    snapshot_download(
        TOKENIZER, revision=TOKENIZER_REVISION, allow_patterns=["*.json", "*.txt"]
    )
    refs = Path(HF_HUB_CACHE) / f"models--{TOKENIZER.replace('/', '--')}" / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    (refs / "main").write_text(TOKENIZER_REVISION)
