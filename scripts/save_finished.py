import argparse
import os
import shutil
import sys

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

def is_nsfw(path="", filename="", flag=False):
    if flag:
        return True
    p = f"{path} {filename}".lower()
    return any(k in p for k in NSFW_KEYWORDS)

def main():
    parser = argparse.ArgumentParser(description="Save satisfied/final image to 成品图 folder")
    parser.add_argument("image", help="Filename or path of the image")
    parser.add_argument("--alias", default="", help="Optional new filename alias")
    parser.add_argument("--nsfw", action="store_true", help="Explicitly categorize under NSFW")
    args = parser.parse_args()

    finished_dir = r"C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\成品图"
    generated_dir = r"C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\生成的图片"
    comfy_out = r"F:\comfyui\ComfyUI\ComfyUI\output"

    src_path = args.image
    if not os.path.exists(src_path):
        candidates = [
            os.path.join(generated_dir, "全年龄", args.image),
            os.path.join(generated_dir, "NSFW", args.image),
            os.path.join(generated_dir, args.image),
            os.path.join(finished_dir, "全年龄", args.image),
            os.path.join(finished_dir, "NSFW", args.image),
            os.path.join(comfy_out, args.image)
        ]
        found = False
        for c in candidates:
            if os.path.exists(c):
                src_path = c
                found = True
                break
        if not found:
            print(f"[Error] Image not found: {args.image}", file=sys.stderr)
            sys.exit(1)

    filename = os.path.basename(src_path)
    if args.alias:
        ext = os.path.splitext(filename)[1]
        if not args.alias.endswith(ext):
            filename = args.alias + ext
        else:
            filename = args.alias

    category = "NSFW" if is_nsfw(src_path, filename, args.nsfw) else "全年龄"
    target_dir = os.path.join(finished_dir, category)
    os.makedirs(target_dir, exist_ok=True)

    dest_path = os.path.join(target_dir, filename)
    shutil.copyfile(src_path, dest_path)
    print(f"[成品图] 满意作品已成功归档至 [{category}]: {dest_path}")

if __name__ == "__main__":
    main()
