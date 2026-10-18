import argparse
import os
import shutil
import sys

def main():
    parser = argparse.ArgumentParser(description="Save satisfied/final image to 成品图 folder")
    parser.add_argument("image", help="Filename or path of the image")
    parser.add_argument("--alias", default="", help="Optional new filename alias")
    args = parser.parse_args()

    finished_dir = r"C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\成品图"
    generated_dir = r"C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\生成的图片"
    comfy_out = r"F:\comfyui\ComfyUI\ComfyUI\output"

    os.makedirs(finished_dir, exist_ok=True)

    src_path = args.image
    if not os.path.exists(src_path):
        c1 = os.path.join(generated_dir, args.image)
        c2 = os.path.join(comfy_out, args.image)
        if os.path.exists(c1):
            src_path = c1
        elif os.path.exists(c2):
            src_path = c2
        else:
            print(f"[Error] Image not found: {args.image}", file=sys.stderr)
            sys.exit(1)

    filename = os.path.basename(src_path)
    if args.alias:
        ext = os.path.splitext(filename)[1]
        if not args.alias.endswith(ext):
            filename = args.alias + ext
        else:
            filename = args.alias

    dest_path = os.path.join(finished_dir, filename)
    shutil.copyfile(src_path, dest_path)
    print(f"[成品图] 满意作品已成功归档至: {dest_path}")

if __name__ == "__main__":
    main()
