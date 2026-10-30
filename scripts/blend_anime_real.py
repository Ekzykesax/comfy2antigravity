#!/usr/bin/env python3
"""
blend_anime_real.py - 2D Anime Character + Real Photographic Background Blend Pipeline
Built on the Togetsukyo Saber Golden Reference Paradigm (渡月桥殿堂级黄金范式).
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
        r"F:\comfyui\ComfyUI\ComfyUI",
        r"F:\comfyui\ComfyUI",
        r"C:\ComfyUI_windows_portable\ComfyUI",
        r"D:\ComfyUI_windows_portable\ComfyUI"
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

def is_nsfw(text="", flag=False):
    if flag:
        return True
    t = text.lower()
    return any(k in t for k in NSFW_KEYWORDS)

def resolve_ref_image(img_path, comfy_input):
    if not img_path:
        return ""
    if os.path.isfile(img_path):
        fname = os.path.basename(img_path)
        dest = os.path.join(comfy_input, fname)
        if not os.path.isfile(dest):
            shutil.copy2(img_path, dest)
        return fname

    ws = os.getcwd()
    candidates = [
        os.path.join(comfy_input, img_path),
        os.path.join(ws, "ComfyUI生图成果", "参考图", "全年龄", img_path),
        os.path.join(ws, "ComfyUI生图成果", "参考图", "NSFW", img_path),
        os.path.join(ws, "ComfyUI生图成果", "参考图", img_path),
        os.path.join(ws, img_path)
    ]
    for c in candidates:
        if os.path.isfile(c):
            dest = os.path.join(comfy_input, os.path.basename(c))
            if not os.path.isfile(dest):
                shutil.copy2(c, dest)
            return os.path.basename(c)
    return img_path

def main():
    parser = argparse.ArgumentParser(description="2D Anime Character + Real Photographic Background Blend Pipeline")
    parser.add_argument("--char-ref", "-c", required=True, help="Character reference image (Image 1)")
    parser.add_argument("--bg-ref", "-b", required=True, help="Real photographic background reference image (Image 2)")
    parser.add_argument("--char-desc", default="", help="Character features, hair, eyes and outfit details")
    parser.add_argument("--bg-desc", default="", help="Real background environment, architecture and atmosphere details")
    parser.add_argument("--pose-desc", default="16:9经典宽画幅电影构图，半身肖像近景特写(upper body medium close-up bust shot)，人物自然位于画面一侧近景，身体微倾自然面向镜头，神态温柔端庄，嘴角带着浅浅柔和的微笑", help="Camera framing, pose and composition")
    parser.add_argument("--resolution", "-r", default="3M", help="Resolution: 3M (2304x1280), 1M (1344x768), 2K (1920x1080), or WxH")
    parser.add_argument("--steps", type=int, default=25, help="Native sampling steps (default: 25)")
    parser.add_argument("--cfg", type=float, default=3.5, help="CFG scale (default: 3.5)")
    parser.add_argument("--seed", type=int, default=0, help="Random seed (0 for random)")
    parser.add_argument("--prefix", default="Anime-RealWorld-Blend", help="Output filename prefix")
    parser.add_argument("--comfy-host", default="http://127.0.0.1:8188", help="ComfyUI API host")
    parser.add_argument("--nsfw", action="store_true", help="Classify output under NSFW")

    args = parser.parse_args()

    if not check_server(args.comfy_host):
        print(f"[Error] ComfyUI server is unreachable at {args.comfy_host}")
        sys.exit(1)

    comfy_root = find_comfy_root()
    comfy_input = os.path.join(comfy_root, "input")
    comfy_output = os.path.join(comfy_root, "output")
    os.makedirs(comfy_input, exist_ok=True)

    char_img = resolve_ref_image(args.char_ref, comfy_input)
    bg_img = resolve_ref_image(args.bg_ref, comfy_input)

    # Resolution mapping
    res_map = {
        "3M": (2304, 1280),
        "1M": (1344, 768),
        "2K": (1920, 1088),
        "4K": (3840, 2160)
    }
    if args.resolution.upper() in res_map:
        w, h = res_map[args.resolution.upper()]
    elif "x" in args.resolution.lower():
        parts = args.resolution.lower().split("x")
        w, h = int(parts[0]), int(parts[1])
    else:
        w, h = 2304, 1280

    char_part = args.char_desc.strip() if args.char_desc.strip() else "长相与画风严格与图1保持高度一致，纯正武内崇/新海诚式清澈二次元灵动动漫五官与眼眸，发型与服装与图1完全一致。"
    bg_part = args.bg_desc.strip() if args.bg_desc.strip() else "实景地貌与建筑氛围完全还原图2中的摄影质感与真实环境细节。"
    pose_part = args.pose_desc.strip()

    # Golden Reference Positive Prompt (渡月桥黄金范式)
    positive_prompt = (
        f"全新的画面与构图：画面中角色的长相、五官、发型与服装严格与图1保持高度一致。\n"
        f"{char_part}\n"
        f"机位景别与构图：{pose_part}。\n"
        f"真实背景与大光圈散景虚化：背景完全还原图2中的{bg_part}，单反相机大光圈光学浅景深散景虚化(cinematic optical bokeh on background, creamy soft bokeh)。画面彻底净化去除所有杂乱游客、行人、车辆与多余杂物。\n"
        f"光影塑造与真实反光（立体感、写实油画般的光影雕塑）：明亮清澈的户外日光与环境漫反射，光影影调层次极为丰富深邃(rich painterly chiaroscuro, volumetric lighting, luminous ambient light)。柔和通透的侧逆轮廓光(glowing rim light on hair, ahoge and shoulders)勾勒出发丝晶莹剔透的高光轮廓，衣物褶皱具备深邃立体的多层环境闭塞阴影与真实柔和反光(sculpted folds, realistic ambient occlusion and fabric reflections)，面容立体饱满、光影通透自然，如同新海诚与精美写实动画电影剧照般，既保留纯正日漫灵动神韵，又具备油画般的厚重体积感与真实反光质感，拒绝死板扁平，绝无油腻塑料假人皮质。\n"
        f"画风铁律：严格禁止黑色描边(no black outlines, lineless soft edge integration, delicate soft contours, clean borderless edges)，形体轮廓纯靠环境光影与明度反差自然切分。\n"
        f"定调核心：anime character seamlessly blended into real photographic background, oil painting cinematic lighting depth, masterpiece, highest quality."
    )

    # Golden Reference Negative Prompt
    negative_prompt = (
        "flat 2d, overly flat, boring flat coloring, paper cut out, flat drawing, "
        "(3d uncanny, 3d render doll, plastic skin, cgi, 3d model, blender render, octane render, wax figure:1.6), "
        "hands, fingers, showing hands, arms reaching down, knees, legs, lower body, full body, wide shot, "
        "(vest:1.8), (sleeveless vest:1.8), (waistcoat:1.8), (corset:1.8), (coat:1.5), (jacket:1.5), "
        "(heavy black outline, thick black lineart, dark outline, black borders, sticker outline, hard black edge:1.6), "
        "(cars, parked cars, vehicles, automobile, trucks, vans, bicycle, crowd, tourists, pedestrians, extra people, trash, clutter:1.5), "
        "(split ahoge, multiple ahoge, branching ahoge, double ahoge:1.4), center framing, stiff pose, deformed, bad anatomy, wrong anatomy, "
        "extra limb, missing limb, floating limbs, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation, "
        "extra fingers, poorly drawn face, poorly drawn hands, oversaturated, harsh flash, low quality, artifacts"
    )

    seed = args.seed if args.seed > 0 else random.randint(1000000000000, 9999999999999)

    workflow = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "NoctQ_V4_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_8b_nvfp4.safetensors", "type": "qwen_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
        "9": {"class_type": "LoadImage", "inputs": {"image": char_img}},
        "10": {"class_type": "LoadImage", "inputs": {"image": bg_img}},
        "4": {
            "class_type": "TextEncodeQwenImage21",
            "inputs": {
                "clip": ["2", 0],
                "vae": ["3", 0],
                "images.image_1": ["9", 0],
                "images.image_2": ["10", 0],
                "prompt": positive_prompt,
                "negative_prompt": negative_prompt,
                "resolution": 0
            }
        },
        "5": {
            "class_type": "EmptyLatentImage",
            "inputs": {"width": w, "height": h, "batch_size": 1}
        },
        "6": {
            "class_type": "KSampler",
            "inputs": {
                "model": ["1", 0],
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
        },
        "7": {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["3", 0]}},
        "8": {"class_type": "SaveImage", "inputs": {"images": ["7", 0], "filename_prefix": args.prefix}}
    }

    nsfw_mode = is_nsfw(args.char_desc + " " + args.pose_desc, args.nsfw)
    if nsfw_mode:
        active_lora = "qwen2_1-femaledVaginus-nsfw-v1_3-fine_L22-31.safetensors"
        workflow["11"] = {
            "class_type": "LoraLoaderModelOnly",
            "inputs": {
                "model": ["1", 0],
                "lora_name": active_lora,
                "strength_model": 0.75
            }
        }
        workflow["6"]["inputs"]["model"] = ["11", 0]
        print(f"[Info] Injected Anatomy LoRA: {active_lora} (Strength: 0.75)")

    print(f"[Info] Character ref: {char_img}")
    print(f"[Info] Background ref: {bg_img}")
    print(f"[Info] Resolution: {w}x{h} ({args.resolution.upper()}) | Steps: {args.steps} | CFG: {args.cfg} | Seed: {seed}")
    print("[Info] Submitting blend job to ComfyUI...")

    payload = json.dumps({"prompt": workflow}).encode("utf-8")
    req = urllib.request.Request(f"{args.comfy_host}/prompt", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        prompt_id = res["prompt_id"]
        print(f"[Success] Prompt queued! Prompt ID: {prompt_id}")

    # Routing
    nsfw_mode = is_nsfw(positive_prompt, args.nsfw)
    cat = "NSFW" if nsfw_mode else "全年龄"
    ws = os.getcwd()
    dest_dir = os.path.join(ws, "ComfyUI生图成果", "生成的图片", cat)
    os.makedirs(dest_dir, exist_ok=True)

    start_time = time.time()
    while True:
        try:
            h_req = urllib.request.urlopen(f"{args.comfy_host}/history/{prompt_id}", timeout=5)
            history = json.loads(h_req.read().decode("utf-8"))
            if prompt_id in history:
                outputs = history[prompt_id].get("outputs", {})
                for node_id, out in outputs.items():
                    if "images" in out:
                        for img in out["images"]:
                            fname = img["filename"]
                            subfolder = img.get("subfolder", "")
                            src_path = os.path.join(comfy_output, subfolder, fname)
                            final_dest = os.path.join(dest_dir, fname)
                            shutil.copy2(src_path, final_dest)
                            print(f"[Completed] Saved to {final_dest}")
                break
        except Exception:
            pass
        time.sleep(5)
        elapsed = int(time.time() - start_time)
        print(f"\r[Rendering] Sampling steps running... ({elapsed}s elapsed)", end="", flush=True)

if __name__ == "__main__":
    main()
