#!/usr/bin/env python3
"""
edit_image.py - Universal High-Fidelity Image Editing Runner
Compatible with DeepSeek Harness (dsh), OpenAI Codex, and Antigravity.
Zero third-party dependencies (pure standard library).
"""

import argparse
import json
import os
import random
import shutil
import sys
import time
import urllib.request
import urllib.error

def check_server(host):
    try:
        req = urllib.request.Request(f"{host}/system_stats")
        with urllib.request.urlopen(req, timeout=3) as resp:
            return resp.status == 200
    except Exception:
        return False

def find_comfy_root():
    if os.environ.get("COMFYUI_ROOT") and os.path.isdir(os.environ["COMFYUI_ROOT"]):
        return os.environ["COMFYUI_ROOT"]
    candidates = [
        r"F:\comfyui\ComfyUI",
        r"C:\ComfyUI_windows_portable",
        r"D:\ComfyUI_windows_portable",
        r"E:\ComfyUI_windows_portable",
        r"C:\ComfyUI",
        r"D:\ComfyUI"
    ]
    for c in candidates:
        if os.path.isdir(c):
            return c
    return candidates[0]

def main():
    parser = argparse.ArgumentParser(description="Universal High-Fidelity Image Editing CLI (DeepSeek Harness & Codex compatible)")
    parser.add_argument("--image", "-i", required=True, help="Target image path to edit")
    parser.add_argument("--prompt", "-p", required=True, help="Editing instruction prompt")
    parser.add_argument("--second-image", "-s", default="", help="Second reference image for outfit or style transfer (optional)")
    parser.add_argument("--negative-prompt", "-n", default="(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation", help="Negative prompt")
    parser.add_argument("--steps", type=int, default=25, help="Official native sampling steps (default: 25)")
    parser.add_argument("--cfg", type=float, default=1.0, help="CFG scale (default: 1.0)")
    parser.add_argument("--resolution", type=int, default=0, help="0 for exact native aspect & resolution (aligned to multiple of 32)")
    parser.add_argument("--seed", type=int, default=0, help="Random seed (0 for random)")
    parser.add_argument("--prefix", default="NoctQ-ImageEdit", help="Output filename prefix")
    parser.add_argument("--comfy-host", default="http://127.0.0.1:8188", help="ComfyUI API host")
    parser.add_argument("--unet", default="NoctQ_V4_int8_convrot.safetensors", help="Diffusion UNet model")
    parser.add_argument("--clip", default="qwen3vl_8b_nvfp4.safetensors", help="Text/vision CLIP encoder")
    parser.add_argument("--vae", default="qwen_image_2.1_vae_bf16.safetensors", help="VAE model")
    parser.add_argument("--output-dir", default="", help="Output archive directory")

    args = parser.parse_args()

    # 1. Check ComfyUI server
    if not check_server(args.comfy_host):
        sys.stderr.write(f"[edit_image.py] Error: ComfyUI server offline at {args.comfy_host}\n")
        sys.exit(1)

    if not os.path.isfile(args.image):
        sys.stderr.write(f"[edit_image.py] Error: Target image not found: {args.image}\n")
        sys.exit(1)

    comfy_root = find_comfy_root()
    input_folder = os.path.join(comfy_root, "ComfyUI", "input")
    os.makedirs(input_folder, exist_ok=True)

    seed = args.seed if args.seed > 0 else random.randint(10000000000000, 99999999999999)

    # 2. Copy image to input folder
    img1_leaf = os.path.basename(args.image)
    dest1 = os.path.join(input_folder, img1_leaf)
    if os.path.abspath(args.image) != os.path.abspath(dest1):
        shutil.copyfile(args.image, dest1)

    img2_leaf = ""
    if args.second_image and os.path.isfile(args.second_image):
        img2_leaf = os.path.basename(args.second_image)
        dest2 = os.path.join(input_folder, img2_leaf)
        if os.path.abspath(args.second_image) != os.path.abspath(dest2):
            shutil.copyfile(args.second_image, dest2)

    # 3. Construct native 25-step image edit prompt graph (NO turbo LoRA, Latent directly anchored)
    prompt_dict = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": args.unet, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": args.clip, "type": "qwen_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": args.vae}},
        "9": {"class_type": "LoadImage", "inputs": {"image": img1_leaf}},
        "4": {
            "class_type": "TextEncodeQwenImage21",
            "inputs": {
                "clip": ["2", 0],
                "vae": ["3", 0],
                "images.image_1": ["9", 0],
                "prompt": args.prompt,
                "negative_prompt": args.negative_prompt,
                "resolution": args.resolution
            }
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],        # Direct pure UNet, NO turbo LoRA
                "positive": ["4", 0],     # Conditioned from TextEncodeQwenImage21
                "negative": ["4", 1],
                "latent_image": ["4", 2], # Latent directly from image_1 to anchor background/face 1:1
                "seed": seed,
                "steps": args.steps,
                "cfg": args.cfg,
                "sampler_name": "euler",
                "scheduler": "simple",
                "denoise": 1.0
            }
        },
        "7": {"class_type": "VAEDecode", "inputs": {"vae": ["3", 0], "samples": ["6", 0]}},
        "8": {"class_type": "SaveImage", "inputs": {"filename_prefix": args.prefix, "images": ["7", 0]}}
    }

    if img2_leaf:
        prompt_dict["11"] = {"class_type": "LoadImage", "inputs": {"image": img2_leaf}}
        prompt_dict["4"]["inputs"]["images.image_2"] = ["11", 0]

    # 4. Submit to ComfyUI
    payload = json.dumps({"prompt": prompt_dict}).encode("utf-8")
    req = urllib.request.Request(f"{args.comfy_host}/prompt", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read().decode("utf-8"))
    prompt_id = result.get("prompt_id")

    # 5. Poll for completion
    timeout = 300
    elapsed = 0
    completed_file = None
    start_time = time.time()

    while elapsed < timeout:
        time.sleep(2)
        elapsed = int(time.time() - start_time)
        try:
            h_req = urllib.request.Request(f"{args.comfy_host}/history/{prompt_id}")
            with urllib.request.urlopen(h_req) as h_resp:
                hist = json.loads(h_resp.read().decode("utf-8"))
            if prompt_id in hist and "outputs" in hist[prompt_id]:
                outputs = hist[prompt_id]["outputs"]
                if "8" in outputs and "images" in outputs["8"]:
                    completed_file = outputs["8"]["images"][0]["filename"]
                    break
        except Exception:
            pass

    if not completed_file:
        sys.stderr.write(f"[edit_image.py] Error: Image edit timed out after {timeout}s\n")
        sys.exit(1)

    # 6. Archive output
    source_path = os.path.join(comfy_root, "ComfyUI", "output", completed_file)
    output_dir = args.output_dir or os.path.join(os.getcwd(), "ComfyUI生图成果", "生成的图片")
    os.makedirs(output_dir, exist_ok=True)
    dest_path = os.path.join(output_dir, completed_file)
    if os.path.isfile(source_path):
        shutil.copyfile(source_path, dest_path)

    # 7. Print standard JSON output for DeepSeek Harness / Codex
    res_obj = {
        "status": "success",
        "prompt_id": prompt_id,
        "filename": completed_file,
        "seed": seed,
        "steps": args.steps,
        "cfg": args.cfg,
        "source_path": source_path,
        "workspace_path": dest_path,
        "elapsed_seconds": elapsed
    }
    print(json.dumps(res_obj, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
