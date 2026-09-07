import io

import torch
from data.processors import get_image_string, get_tokenizer
from download import MODEL, MODEL_REVISION
from fastapi import FastAPI, UploadFile
from fastapi.responses import Response
from models.vision_language_model import VisionLanguageModel
from PIL import Image
from torchvision.transforms.functional import to_tensor

SIZE = 512
PROMPT = "What kind of beer is this? Otherwise if not beer, answer with only 'no'"

model = VisionLanguageModel.from_pretrained(MODEL, revision=MODEL_REVISION).eval()
tokenizer = get_tokenizer(
    model.cfg.lm_tokenizer,
    model.cfg.vlm_extra_tokens,
    model.cfg.lm_chat_template,
)
image_string = get_image_string(tokenizer, [(1, 1)], model.cfg.mp_image_token_length)

app = FastAPI()


@app.post("/classify")
async def classify(photo: UploadFile) -> Response:
    picture = (
        Image.open(io.BytesIO(await photo.read())).convert("RGB").resize((SIZE, SIZE))
    )
    image = to_tensor(picture).unsqueeze(0)

    messages = [{"role": "user", "content": image_string + PROMPT}]
    encoded = tokenizer.apply_chat_template(
        messages, tokenize=True, add_generation_prompt=True
    )
    ids = encoded.input_ids if hasattr(encoded, "input_ids") else encoded
    input_ids = torch.tensor(ids).unsqueeze(0)

    with torch.inference_mode():
        generated = model.generate(input_ids, image, max_new_tokens=64, greedy=True)

    raw = tokenizer.decode(generated[0].tolist(), skip_special_tokens=True).encode(
        "utf-8"
    )
    return Response(content=raw, media_type="application/octet-stream")
