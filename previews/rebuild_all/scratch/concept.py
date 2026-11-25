# python concept.py <name> <seed from> <seed to>: fresh concept pictures with SDXL-Turbo (local), like Rolo's
import sys, time, torch
from diffusers import AutoPipelineForText2Image
P = {
 "nina": ("3D render of a cute cartoon baby hippo girl character, full body, standing upright like a person, front three-quarter view, "
          "chunky rounded toy-like proportions, big round head, soft grey-brown hippo skin, wide hippo snout with two nostrils, "
          "two little front teeth, small round ears, big shiny brown eyes with lashes, long straight bright red hair with a big red bow, "
          "white t-shirt, pink denim overalls, yellow backpack, pink sneakers, pixar style, smooth clean shapes, soft lighting, "
          "plain white background, whole body visible"),
 "mr_palmer2": ("cute 3D cartoon chubby old mayor, wide yellow sash diagonally across his chest with a big gold rosette, navy blue suit, "
          "red tie, white shirt, fluffy white hair, round black glasses, big white moustache, round tummy, standing, full body, "
          "pixar style, plain white background"),
 "mr_palmer": ("3D render of a cute cartoon old man mayor character, full body, standing, front three-quarter view, chunky rounded "
          "toy-like proportions, big round head, round tummy, fluffy white hair, big round black glasses, big white moustache, rosy "
          "cheeks, smiling, navy blue suit, white shirt, red tie, yellow sash across his chest with a gold rosette, brown shoes, "
          "pixar style, smooth clean shapes, soft lighting, plain white background, whole body visible"),
}
name = sys.argv[1]
t = time.time()
pipe = AutoPipelineForText2Image.from_pretrained("stabilityai/sdxl-turbo", torch_dtype=torch.float16, variant="fp16").to("cuda")
neg = "cropped, cut off, multiple characters, text, realistic, scary"
for seed in range(int(sys.argv[2]), int(sys.argv[3])):
    g = torch.Generator("cuda").manual_seed(seed)
    img = pipe(prompt=P[name], negative_prompt=neg, num_inference_steps=4, guidance_scale=0.0, width=768, height=768, generator=g).images[0]
    img.save(f"{name}_{seed}.png")
print("done", round(time.time()-t, 1), "s")
