# Agent Instructions: comfy2antigravity

This repository provides image generation and universal high-fidelity image editing capabilities via a local ComfyUI instance (`http://127.0.0.1:8188`).

Compatible with **DeepSeek Harness (`dsh`)**, **OpenAI Codex**, and **Antigravity**.

---

## 1. Tool Execution Guidelines for Agents

All scripts are cross-platform Python 3 CLI utilities using the standard library (no extra pip dependencies required). They output standard JSON to `stdout` upon completion.

### Tool 1: Text-to-Image & Reference-Image Generation
Used for generating brand new images or character-consistent artwork.
- **Script**: `scripts/generate.py`
- **Sampling**: Viggle Turbo 8-step (`Euler / Simple`, Steps: 8, CFG: 1.0)
- **Usage**:
  ```bash
  python scripts/generate.py --prompt "<your prompt>" [--ref-image "<path>"] [--width 896] [--height 1152]
  ```
- **Example**:
  ```bash
  python scripts/generate.py --prompt "Cyberpunk rainy street at night, reflective puddles, cinematic lighting" --width 1344 --height 768
  ```

### Tool 2: Universal High-Fidelity Image Editing
Used for modifying existing images: changing outfits, altering hairstyles, modifying postures, adjusting background/lighting, or adding/removing objects.
- **Script**: `scripts/edit_image.py`
- **Sampling**: Official native 25-step (`Euler / Simple`, Steps: 25, CFG: 1.0, **NO turbo LoRA**)
- **Latent Mapping**: Anchored directly to original image latent (`resolution: 0`), guaranteeing 1:1 pixel fidelity for non-edited areas.
- **Usage**:
  ```bash
  python scripts/edit_image.py --image "<image_path>" --prompt "<edit instruction>" [--second-image "<ref_path>"]
  ```
- **Example (Single-image edit)**:
  ```bash
  python scripts/edit_image.py --image "input/photo.jpg" --prompt "Change the casual jacket to an elegant black evening dress, keep face and background unchanged"
  ```
- **Example (Dual-image style/outfit transfer)**:
  ```bash
  python scripts/edit_image.py --image "input/person.jpg" --second-image "input/dress.png" --prompt "Replace the outfit in image 1 with the dress design in image 2, preserve face and background"
  ```

### Tool 3: 4K Focus-Aware Bokeh-Preserving Upscale
Used for upscaling images to 4K (3840px+) while strictly preserving optical camera depth-of-field bokeh (preventing artificial over-sharpening of blurred backgrounds). Output automatically synchronizes to `ComfyUI生图成果/成品图/` (categorized under `全年龄/` or `NSFW/`).
- **Script**: `scripts/upscale_image.py`
- **Model**: `4x_foolhardy_Remacri.pth` (with dual-stream gradient-feathered focus fusion)
- **Usage**:
  ```bash
  python scripts/upscale_image.py --image "<image_path>" [--target_width 3840] [--target_height 0] [--model "4x_foolhardy_Remacri.pth"] [--nsfw]
  ```
- **Example**:
  ```bash
  python scripts/upscale_image.py --image "output/portrait.png" --target_width 3840
  ```

### Tool 4: Archive Satisfied / Final Masterpiece
Used for archiving any user-approved, satisfactory image (4K or non-4K) into the dedicated `ComfyUI生图成果/成品图/` gallery (subdivided into `全年龄/` and `NSFW/`).
- **Script**: `scripts/save_finished.py`
- **Usage**:
  ```bash
  python scripts/save_finished.py "<image_path_or_filename>" [--alias "<custom_name>"] [--nsfw]
  ```

---

## 2. Standard Output Specification

All CLI tools return a clean JSON object to `stdout`:

```json
{
  "status": "success",
  "prompt_id": "07ac678b-17e5-4563-84a1-ef93a11e927b",
  "filename": "NoctQ-ImageEdit_00001_.png",
  "seed": 16372925266269,
  "source_path": "F:\\comfyui\\ComfyUI\\ComfyUI\\output\\NoctQ-ImageEdit_00001_.png",
  "workspace_path": "C:\\path\\to\\ComfyUI生图成果\\生成的图片\\NoctQ-ImageEdit_00001_.png",
  "elapsed_seconds": 28
}
```

Agents can parse the `workspace_path` or `filename` from stdout and display it to the user.
