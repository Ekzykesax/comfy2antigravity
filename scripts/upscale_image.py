import argparse
import json
import os
import shutil
import sys
import time
import urllib.request
import numpy as np
from PIL import Image
import scipy.ndimage as ndi

COMFY_HOST = "http://127.0.0.1:8188"
DEFAULT_MODEL = "4x_foolhardy_Remacri.pth"

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

def is_nsfw(path="", prefix="", flag=False):
    if flag:
        return True
    p = f"{path} {prefix}".lower()
    return any(k in p for k in NSFW_KEYWORDS)

def parse_args():
    parser = argparse.ArgumentParser(description="Focus-Aware 4K Bokeh-Preserved Upscaler")
    parser.add_argument("--image", required=True, help="Path or filename of the image to upscale")
    parser.add_argument("--target_width", type=int, default=3840, help="Target 4K width (default: 3840)")
    parser.add_argument("--target_height", type=int, default=0, help="Target 4K height (0 = auto keep aspect ratio)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Upscale model name in ComfyUI")
    parser.add_argument("--prefix", default="4K-Remacri-Bokeh", help="Output prefix")
    parser.add_argument("--disable_bokeh_preserve", action="store_true", help="Disable dual-stream bokeh preservation")
    parser.add_argument("--nsfw", action="store_true", help="Explicitly mark as NSFW")
    return parser.parse_args()

def main():
    args = parse_args()
    comfy_root = r"F:\comfyui\ComfyUI\ComfyUI"
    comfy_input = os.path.join(comfy_root, "input")
    comfy_output = os.path.join(comfy_root, "output")
    ws_root = r"C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果"

    # 1. Resolve source image across all subfolders
    src_img = args.image
    if not os.path.exists(src_img):
        candidates = [
            os.path.join(comfy_output, src_img),
            os.path.join(comfy_input, src_img),
            os.path.join(ws_root, "生成的图片", "全年龄", src_img),
            os.path.join(ws_root, "生成的图片", "NSFW", src_img),
            os.path.join(ws_root, "成品图", "全年龄", src_img),
            os.path.join(ws_root, "成品图", "NSFW", src_img),
            os.path.join(ws_root, "生成的图片", src_img),
            os.path.join(ws_root, "成品图", src_img)
        ]
        found = False
        for c in candidates:
            if os.path.exists(c):
                src_img = c
                found = True
                break
        if not found:
            print(f"[Error] Source image not found: {args.image}")
            sys.exit(1)

    filename = os.path.basename(src_img)
    dest_input = os.path.join(comfy_input, filename)
    if os.path.abspath(src_img) != os.path.abspath(dest_input):
        shutil.copyfile(src_img, dest_input)

    im_orig = Image.open(src_img).convert("RGB")
    orig_w, orig_h = im_orig.size
    aspect_ratio = orig_w / orig_h

    target_w = args.target_width
    target_h = args.target_height
    if target_h <= 0:
        target_h = round(target_w / aspect_ratio / 32) * 32

    print(f"[Upscale] Base image: {orig_w}x{orig_h} -> Target 4K: {target_w}x{target_h}")

    # 2. Submit ComfyUI Upscale with Model (Remacri)
    workflow = {
        "1": {
            "class_type": "LoadImage",
            "inputs": {"image": filename}
        },
        "2": {
            "class_type": "UpscaleModelLoader",
            "inputs": {"model_name": args.model}
        },
        "3": {
            "class_type": "ImageUpscaleWithModel",
            "inputs": {"upscale_model": ["2", 0], "image": ["1", 0]}
        },
        "4": {
            "class_type": "ImageScale",
            "inputs": {
                "image": ["3", 0],
                "upscale_method": "lanczos",
                "width": target_w,
                "height": target_h,
                "crop": "disabled"
            }
        },
        "5": {
            "class_type": "SaveImage",
            "inputs": {
                "filename_prefix": args.prefix + "-Raw",
                "images": ["4", 0]
            }
        }
    }

    data = json.dumps({"prompt": workflow}).encode("utf-8")
    req = urllib.request.Request(f"{COMFY_HOST}/prompt", data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        res = json.loads(resp.read().decode("utf-8"))
        prompt_id = res["prompt_id"]

    print(f"[Upscale] Prompt ID: {prompt_id}. Waiting for neural tiled rendering...")
    raw_4k_name = None
    start = time.time()
    while time.time() - start < 300:
        time.sleep(2)
        try:
            with urllib.request.urlopen(f"{COMFY_HOST}/history/{prompt_id}") as resp:
                hist = json.loads(resp.read().decode("utf-8"))
                if prompt_id in hist:
                    status = hist[prompt_id].get("status", {})
                    if status.get("completed", False):
                        outputs = hist[prompt_id].get("outputs", {})
                        raw_4k_name = outputs["5"]["images"][0]["filename"]
                        break
                    elif status.get("status_str") == "error":
                        print("[Upscale] Error:", hist[prompt_id])
                        sys.exit(1)
        except Exception:
            pass

    if not raw_4k_name:
        print("[Upscale] Timeout.")
        sys.exit(1)

    raw_4k_path = os.path.join(comfy_output, raw_4k_name)

    # 3. Focus-Aware Bokeh Preservation Dual-Stream Fusion
    if args.disable_bokeh_preserve:
        final_path = raw_4k_path
    else:
        print("[Upscale] Applying Focus-Aware Bokeh Preservation...")
        im_sharp = Image.open(raw_4k_path).convert("RGB")
        im_smooth = im_orig.resize((target_w, target_h), Image.Resampling.LANCZOS)

        # Compute focus energy on original base
        gray = np.array(im_orig.convert("L"), dtype=np.float32)
        gx = ndi.sobel(gray, axis=1)
        gy = ndi.sobel(gray, axis=0)
        grad_mag = np.hypot(gx, gy)
        focus = ndi.gaussian_filter(grad_mag, sigma=8.0)

        p30 = np.percentile(focus, 30)
        p85 = np.percentile(focus, 85)
        focus_norm = np.clip((focus - p30) / (p85 - p30 + 1e-5), 0.0, 1.0)

        # Center/foreground subject prior
        H, W = gray.shape
        y_coords, x_coords = np.ogrid[:H, :W]
        subject_prior = np.exp(-((x_coords - W*0.4)**2 / (2 * (W*0.25)**2) + (y_coords - H*0.55)**2 / (2 * (H*0.45)**2)))
        subject_prior = np.clip(subject_prior * 1.5, 0, 1)

        combined_mask = np.maximum(focus_norm, subject_prior * 0.95)
        combined_mask = ndi.gaussian_filter(combined_mask, sigma=12.0)

        mask_img = Image.fromarray((combined_mask * 255).astype(np.uint8)).resize((target_w, target_h), Image.Resampling.BICUBIC)
        mask_arr = np.array(mask_img, dtype=np.float32)[:, :, None] / 255.0

        arr_sharp = np.array(im_sharp, dtype=np.float32)
        arr_smooth = np.array(im_smooth, dtype=np.float32)

        blended = arr_sharp * mask_arr + arr_smooth * (1.0 - mask_arr)
        blended = np.clip(blended, 0, 255).astype(np.uint8)

        final_img = Image.fromarray(blended)
        final_filename = args.prefix + ".png"
        final_path = os.path.join(comfy_output, final_filename)
        final_img.save(final_path)

    # 4. Local Workspace & Finished Archive (4K = Satisfied Masterpiece, SFW/NSFW sorted)
    category = "NSFW" if is_nsfw(src_img, args.prefix, args.nsfw) else "全年龄"
    ws_category_dir = os.path.join(ws_root, "生成的图片", category)
    finished_category_dir = os.path.join(ws_root, "成品图", category)
    os.makedirs(ws_category_dir, exist_ok=True)
    os.makedirs(finished_category_dir, exist_ok=True)

    dest_ws = os.path.join(ws_category_dir, os.path.basename(final_path))
    dest_fin = os.path.join(finished_category_dir, os.path.basename(final_path))
    shutil.copyfile(final_path, dest_ws)
    shutil.copyfile(final_path, dest_fin)
    print(f"PIPELINE_COMPLETE: {final_path} -> [{category}] {dest_fin}")

if __name__ == "__main__":
    main()
