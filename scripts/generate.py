#!/usr/bin/env python3
"""
generate.py - Text-to-Image & Reference-to-Image Generation Runner
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

NSFW_KEYWORDS = [
    "nsfw", "nude", "naked", "topless", "bottomless", "pussy", "slit", "vulva",
    "genitals", "anus", "nipple", "breast", "cleavage", "bareback", "braless",
    "lingerie", "bikini", "thong", "microbikini", "sheer", "mesh", "lace", "crotch",
    "boudoir", "gravure", "spreadlegs", "backhips", "sexy", "venus", "sensual",
    "bath", "69", "pronelie", "shower", "penetration", "vaginal", "pelvic", "busty",
    "uncensored", "sultry", "macro-slit", "realanatomy",
    "裸", "全裸", "半裸", "去衣", "脱衣", "私密", "一线天", "阴部", "阴唇",
    "乳头", "巨乳", "乳晕", "下体", "情趣", "透视", "内衣", "比基尼", "丁字裤"
]

def is_nsfw(prompt="", flag=False):
    if flag:
        return True
    p = prompt.lower()
    return any(k in p for k in NSFW_KEYWORDS)

def resolve_reference(ref_path, comfy_input):
    if not ref_path:
        return ""
    if os.path.isfile(ref_path):
        return os.path.abspath(ref_path)
    ws_root = os.getcwd()
    candidates = [
        os.path.join(comfy_input, ref_path),
        os.path.join(ws_root, "ComfyUI生图成果", "参考图", ref_path),
        os.path.join(ws_root, "ComfyUI生图成果", "参考图", "全年龄", ref_path),
        os.path.join(ws_root, "ComfyUI生图成果", "参考图", "NSFW", ref_path),
        os.path.join(ws_root, "ComfyUI生图成果", "生成的图片", "全年龄", ref_path),
        os.path.join(ws_root, "ComfyUI生图成果", "生成的图片", "NSFW", ref_path),
    ]
    for c in candidates:
        if os.path.isfile(c):
            return os.path.abspath(c)
    return ""

def main():
    parser = argparse.ArgumentParser(description="ComfyUI Image Generation CLI (DeepSeek Harness & Codex compatible)")
    parser.add_argument("--prompt", "-p", required=True, help="Text prompt for image generation")
    parser.add_argument("--ref-image", "-r", default="", help="Path to reference image (optional)")
    parser.add_argument("--ref-image2", default="", help="Path to second reference image (optional)")
    parser.add_argument("--width", type=int, default=896, help="Image width (default: 896)")
    parser.add_argument("--height", type=int, default=1152, help="Image height (default: 1152)")
    parser.add_argument("--steps", type=int, default=8, help="Sampling steps (default: 8 for Viggle Turbo)")
    parser.add_argument("--cfg", type=float, default=1.0, help="CFG scale (default: 1.0)")
    parser.add_argument("--sampler", default="viggle", choices=["viggle", "native", "euler"], help="Sampler pipeline")
    parser.add_argument("--seed", type=int, default=0, help="Random seed (0 for random)")
    parser.add_argument("--prefix", default="Viggle8-Qwen-Gen", help="Filename prefix")
    parser.add_argument("--comfy-host", default="http://127.0.0.1:8188", help="ComfyUI API host")
    parser.add_argument("--unet", default="NoctQ_V4_int8_convrot.safetensors", help="Diffusion UNet model")
    parser.add_argument("--clip", default="qwen3vl_8b_nvfp4.safetensors", help="Text/vision CLIP encoder")
    parser.add_argument("--vae", default="qwen_image_2.1_vae_bf16.safetensors", help="VAE model")
    parser.add_argument("--lora", default="Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors", help="Turbo LoRA model")
    parser.add_argument("--nsfw", action="store_true", help="Explicitly classify output under NSFW")
    parser.add_argument("--output-dir", default="", help="Output archive directory")

    args = parser.parse_args()

    # 1. Check ComfyUI server
    if not check_server(args.comfy_host):
        sys.stderr.write(f"[generate.py] Error: ComfyUI server offline at {args.comfy_host}\n")
        sys.exit(1)

    comfy_root = find_comfy_root()
    input_folder = os.path.join(comfy_root, "ComfyUI", "input")
    os.makedirs(input_folder, exist_ok=True)

    seed = args.seed if args.seed > 0 else random.randint(10000000000000, 99999999999999)

    # 2. Handle reference images
    ref1_leaf = ""
    resolved_ref1 = resolve_reference(args.ref_image, input_folder)
    if resolved_ref1:
        ref1_leaf = os.path.basename(resolved_ref1)
        dest1 = os.path.join(input_folder, ref1_leaf)
        if os.path.abspath(resolved_ref1) != os.path.abspath(dest1):
            shutil.copyfile(resolved_ref1, dest1)

    ref2_leaf = ""
    resolved_ref2 = resolve_reference(args.ref_image2, input_folder)
    if resolved_ref2:
        ref2_leaf = os.path.basename(resolved_ref2)
        dest2 = os.path.join(input_folder, ref2_leaf)
        if os.path.abspath(resolved_ref2) != os.path.abspath(dest2):
            shutil.copyfile(resolved_ref2, dest2)

    # 3. Build prompt graph
    prompt_dict = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": args.unet, "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": args.clip, "type": "qwen_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": args.vae}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": args.width, "height": args.height, "batch_size": 1}},
        "7": {"class_type": "VAEDecode", "inputs": {"vae": ["3", 0], "samples": ["6", 0]}},
        "8": {"class_type": "SaveImage", "inputs": {"filename_prefix": args.prefix, "images": ["7", 0]}}
    }

    if ref1_leaf:
        prompt_dict["9"] = {"class_type": "LoadImage", "inputs": {"image": ref1_leaf}}
        encode_inputs = {
            "clip": ["2", 0],
            "vae": ["3", 0],
            "images.image_1": ["9", 0],
            "prompt": args.prompt,
            "negative_prompt": "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, blurry",
            "resolution": 1024
        }
        if ref2_leaf:
            prompt_dict["10"] = {"class_type": "LoadImage", "inputs": {"image": ref2_leaf}}
            encode_inputs["images.image_2"] = ["10", 0]
        prompt_dict["4"] = {"class_type": "TextEncodeQwenImage21", "inputs": encode_inputs}
    else:
        prompt_dict["4"] = {
            "class_type": "TextEncodeQwenImage21",
            "inputs": {
                "clip": ["2", 0],
                "vae": ["3", 0],
                "prompt": args.prompt,
                "negative_prompt": "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, blurry",
                "resolution": 1024
            }
        }

    if args.sampler == "viggle":
        prompt_dict["12"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "model": ["1", 0],
                "clip": ["2", 0],
                "lora_name": args.lora,
                "strength_model": 1.0,
                "strength_clip": 1.0
            }
        }
        sampler_model = ["12", 0]
    else:
        sampler_model = ["1", 0]

    prompt_dict["6"] = {
        "class_type": "KSampler",
        "inputs": {
            "model": sampler_model,
            "positive": ["4", 0],
            "negative": ["4", 1],
            "latent_image": ["5", 0],
            "seed": seed,
            "steps": args.steps,
            "cfg": args.cfg,
            "sampler_name": "euler",
            "scheduler": "simple",
            "denoise": 1.0
        }
    }

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
        sys.stderr.write(f"[generate.py] Error: Generation timed out after {timeout}s\n")
        sys.exit(1)

    # 6. Archive to workspace with automatic SFW / NSFW categorization
    source_path = os.path.join(comfy_root, "ComfyUI", "output", completed_file)
    category = "NSFW" if is_nsfw(args.prompt, args.nsfw) else "全年龄"
    output_dir = args.output_dir or os.path.join(os.getcwd(), "ComfyUI生图成果", "生成的图片", category)
    os.makedirs(output_dir, exist_ok=True)
    dest_path = os.path.join(output_dir, completed_file)
    if os.path.isfile(source_path):
        shutil.copyfile(source_path, dest_path)

    # 7. Print standard JSON output for DeepSeek Harness / Codex
    res_obj = {
        "status": "success",
        "prompt_id": prompt_id,
        "filename": completed_file,
        "category": category,
        "seed": seed,
        "source_path": source_path,
        "workspace_path": dest_path,
        "elapsed_seconds": elapsed
    }
    print(json.dumps(res_obj, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
