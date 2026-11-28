#!/bin/bash
# Style test C: a small SDXL style LoRA ("sofistyle") trained on Sofi's pictures with kohya sd-scripts (Apache-2.0,
# in ai3d/sdscripts with its own venv), sized for a 12 GB card: U-Net only, latents and text cached, 8-bit AdamW,
# gradient checkpointing, bf16. The pictures and captions are in ai3d/style_test/C/data/10_sofistyle (10 repeats each).
#   bash train_style.sh [epochs]
SD=/c/Users/hggru/Game_dev/ai3d/sdscripts
C=/c/Users/hggru/Game_dev/ai3d/style_test/C
BASE=$(ls -d ~/.cache/huggingface/hub/models--stabilityai--stable-diffusion-xl-base-1.0/snapshots/*/ | head -1)
cd "$SD" || exit 1
venv/Scripts/python.exe sdxl_train_network.py \
  --pretrained_model_name_or_path="$BASE" \
  --train_data_dir="$C/data" --output_dir="$C/lora" --output_name=sofistyle \
  --resolution=1024,1024 --enable_bucket --caption_extension=.txt \
  --network_module=networks.lora --network_dim=16 --network_alpha=8 --network_train_unet_only \
  --learning_rate=1e-4 --optimizer_type=AdamW8bit --lr_scheduler=cosine --lr_warmup_steps=50 \
  --train_batch_size=1 --max_train_epochs="${1:-4}" --save_every_n_epochs=1 \
  --mixed_precision=bf16 --save_precision=fp16 --gradient_checkpointing --sdpa \
  --cache_latents --cache_text_encoder_outputs --no_half_vae \
  --save_model_as=safetensors --seed=2025 --max_data_loader_n_workers=0
