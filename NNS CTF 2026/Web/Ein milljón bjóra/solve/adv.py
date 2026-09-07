import io, sys, torch, torch.nn.functional as F
from PIL import Image
from torchvision.transforms.functional import to_tensor
from data.processors import get_image_string, get_tokenizer
from download import MODEL, MODEL_REVISION
from models.vision_language_model import VisionLanguageModel

torch.set_num_threads(6)
SIZE=512
PROMPT="What kind of beer is this? Otherwise if not beer, answer with only 'no'"
TARGET = sys.argv[1] if len(sys.argv)>1 else "this is a beer  cold golden lager brew tasty yum"
STEPS = int(sys.argv[2]) if len(sys.argv)>2 else 200

model = VisionLanguageModel.from_pretrained(MODEL, revision=MODEL_REVISION).eval()
for p in model.parameters(): p.requires_grad_(False)
tok = get_tokenizer(model.cfg.lm_tokenizer, model.cfg.vlm_extra_tokens, model.cfg.lm_chat_template)
image_string = get_image_string(tok, [(1,1)], model.cfg.mp_image_token_length)
messages=[{"role":"user","content":image_string+PROMPT}]
enc = tok.apply_chat_template(messages, tokenize=True, add_generation_prompt=True)
prompt_ids = enc.input_ids if hasattr(enc,"input_ids") else enc
prompt_ids = list(prompt_ids)

tgt_ids = tok.encode(TARGET, add_special_tokens=False)
eos = tok.eos_token_id
full = prompt_ids + tgt_ids + [eos]
full_t = torch.tensor(full).unsqueeze(0)
ans_start = len(prompt_ids)
ans_ids = tgt_ids + [eos]
print("prompt_len",len(prompt_ids),"target_tokens",len(tgt_ids),"decoded_target=",repr(tok.decode(tgt_ids)))

img = torch.rand(1,3,SIZE,SIZE)*0.2+0.4
img.requires_grad_(True)
opt = torch.optim.Adam([img], lr=0.05)

image_token_id = tok.image_token_id

def logits_for(image):
    token_embd = model.decoder.token_embedding(full_t)
    image_embd = model.MP(model.vision_encoder(image))
    token_embd = model._replace_img_tokens_with_embd(full_t, token_embd, image_embd)
    hidden,_ = model.decoder(token_embd)
    return model.decoder.head(hidden)

for step in range(STEPS):
    opt.zero_grad()
    im = img.clamp(0,1)
    logits = logits_for(im)
    loss = 0.0
    correct = 0
    for k,tid in enumerate(ans_ids):
        pos = ans_start + k - 1
        lg = logits[0,pos]
        loss = loss + F.cross_entropy(lg.unsqueeze(0), torch.tensor([tid]))
        if lg.argmax().item()==tid: correct+=1
    loss.backward()
    opt.step()
    with torch.no_grad(): img.clamp_(0,1)
    if step%10==0 or correct==len(ans_ids):
        print(f"step {step} loss {loss.item():.3f} correct {correct}/{len(ans_ids)}")
    if correct==len(ans_ids) and step>20:
        print("all correct (teacher-forced)"); break

from torchvision.transforms.functional import to_pil_image
pil = to_pil_image(img.detach().clamp(0,1)[0])
pil.save("adv.png")
pil.save("adv_q100.jpg", quality=100, subsampling=0)
pil.save("adv_q95.jpg", quality=95, subsampling=0)
print("saved adv.png adv_q100.jpg adv_q95.jpg")

def run_generate(path):
    picture = Image.open(path).convert("RGB").resize((SIZE,SIZE))
    image = to_tensor(picture).unsqueeze(0)
    ids = torch.tensor(prompt_ids).unsqueeze(0)
    with torch.inference_mode():
        gen = model.generate(ids, image, max_new_tokens=64, greedy=True)
    out = tok.decode(gen[0].tolist(), skip_special_tokens=True)
    return out
for path in ["adv.png","adv_q100.jpg","adv_q95.jpg"]:
    out = run_generate(path)
    print(path, "->", repr(out), "| len", len(out.encode()), "| MATCH", out==TARGET)
