# Universal Agent Guidelines: comfy2antigravity

This repository provides image generation, high-fidelity universal editing, anime-real photo blending, and 4K optical bokeh-preserving upscaling via a local ComfyUI instance (`http://127.0.0.1:8188`).

Engineered for **all AI coding agents and LLM harnesses**, including:
- **Anthropic Claude Code**
- **Cursor** (Rules / Agent mode)
- **Windsurf** (`.windsurfrules` / Cascade)
- **Roo Code & Cline** (VS Code autonomous agents)
- **Google Antigravity** (Native Skill)
- **OpenCode & Aider** (CLI coding agents)
- **DeepSeek Harness (`dsh`)**
- **OpenAI Codex & Custom Python Agents**

---

## 1. Core Principles for AI Agents

1. **Zero UI Interaction Needed**: Agents never need to touch the ComfyUI canvas or manually connect noodles. All complexity is handled programmatically via standard CLI tools.
2. **Pure Standard Library**: All Python scripts in `scripts/` use pure Python 3 standard library modules (`urllib`, `json`, `argparse`, `shutil`, `sys`). No external pip dependencies required.
3. **Structured JSON Output**: All tools output clean, parseable JSON to `stdout` upon task completion, enabling programmatic parsing of generated paths and metadata.
4. **Categorized Asset Management**: Outputs are automatically sorted into `ComfyUI生图成果/` with strict segregation between `全年龄/` (General / All-Ages) and `NSFW/` directories.
5. **Auto-Start & Healing**: Before sending prompts, scripts automatically probe ComfyUI server availability at `http://127.0.0.1:8188/system_stats`.

---

## 2. Tool Reference for AI Agents

### Tool 1: Text-to-Image & Reference-Image Generation
Used for generating brand new images or character-consistent artwork.
- **Script**: `scripts/generate.py`
- **Sampling**: Viggle Turbo 8-step (`Euler / Simple`, Steps: 8, CFG: 1.0)
- **CLI Usage**:
  ```bash
  python scripts/generate.py --prompt "<your prompt>" [--ref-image "<path>"] [--width 896] [--height 1152] [--nsfw]
  ```
- **Example**:
  ```bash
  python scripts/generate.py --prompt "Cyberpunk rainy street at night, neon reflections on puddles, cinematic lighting" --width 1344 --height 768
  ```

### Tool 2: Universal High-Fidelity Image Editing
Used for modifying existing images: outfit replacement, hairstyle alteration, pose adjustment, background/lighting modification, or adding/removing objects.
- **Script**: `scripts/edit_image.py`
- **Sampling**: Native 25-step (`Euler / Simple`, Steps: 25, CFG: 1.0, **NO turbo LoRA**)
- **Latent Mapping**: Anchored directly to original image latent (`resolution: 0`), guaranteeing 1:1 pixel fidelity for non-edited areas.
- **CLI Usage**:
  ```bash
  python scripts/edit_image.py --image "<image_path>" --prompt "<edit instruction>" [--second-image "<ref_path>"] [--nsfw]
  ```
- **Example (Single-image edit)**:
  ```bash
  python scripts/edit_image.py --image "input/photo.jpg" --prompt "Change the casual jacket to an elegant black evening dress, keep face and background unchanged"
  ```
- **Example (Dual-image style/outfit transfer)**:
  ```bash
  python scripts/edit_image.py --image "input/person.jpg" --second-image "input/dress.png" --prompt "Replace the outfit in image 1 with the dress design in image 2, preserve face and background"
  ```

### Tool 3: 2D Anime + Real-Photo Blending
Used for seamlessly blending 2D anime characters into real-world photographic scenery, applying oil-painting depth and optical bokeh while strictly avoiding 3D plastic artifacts and heavy black outlines.
- **Script**: `scripts/blend_anime_real.py`
- **Sampling**: Native 25-step (`Euler / Simple`, Steps: 25, CFG: 3.5)
- **CLI Usage**:
  ```bash
  python scripts/blend_anime_real.py --char-ref "<character_ref>" --bg-ref "<real_photo_bg>" [--char-desc "<features>"] [--bg-desc "<scenery>"] [--resolution "3M"] [--nsfw]
  ```
- **Example**:
  ```bash
  python scripts/blend_anime_real.py --char-ref "saber_ref.png" --bg-ref "kyoto_togetsukyo.jpg" --resolution "3M"
  ```

### Tool 4: 4K Focus-Aware Bokeh-Preserving Upscale
Used for upscaling images to 4K (3840px+) while strictly preserving natural optical camera depth-of-field bokeh (preventing artificial over-sharpening of blurred backgrounds).
- **Script**: `scripts/upscale_image.py`
- **Model**: `4x_foolhardy_Remacri.pth` (with dual-stream gradient-feathered focus fusion)
- **CLI Usage**:
  ```bash
  python scripts/upscale_image.py --image "<image_path>" [--target_width 3840] [--target_height 0] [--model "4x_foolhardy_Remacri.pth"] [--nsfw]
  ```
- **Example**:
  ```bash
  python scripts/upscale_image.py --image "output/portrait.png" --target_width 3840
  ```

### Tool 5: Archive Masterpiece / Satisfied Artwork
Used for archiving any user-approved, satisfactory image into the dedicated `ComfyUI生图成果/成品图/` gallery (subdivided into `全年龄/` and `NSFW/`).
- **Script**: `scripts/save_finished.py`
- **CLI Usage**:
  ```bash
  python scripts/save_finished.py "<image_path_or_filename>" [--alias "<custom_name>"] [--nsfw]
  ```

---

## 3. Standard JSON Output Specification

All CLI tools return a clean JSON object to `stdout`:

```json
{
  "status": "success",
  "prompt_id": "07ac678b-17e5-4563-84a1-ef93a11e927b",
  "filename": "NoctQ-ImageEdit_00001_.png",
  "seed": 16372925266269,
  "source_path": "F:\\comfyui\\ComfyUI\\ComfyUI\\output\\NoctQ-ImageEdit_00001_.png",
  "workspace_path": "C:\\path\\to\\ComfyUI生图成果\\生成的图片\\NoctQ-ImageEdit_00001_.png"
}
```

Agents can parse the `workspace_path` or `filename` from stdout to present or verify the generated image.

---

## 4. Multi-Agent Setup Quickstart

- **Claude Code**: Reference this file in your project or call `python scripts/<tool>.py` directly in bash tool calls.
- **Cursor / Windsurf**: Add a rule in `.cursorrules` or `.windsurfrules` pointing to `AGENTS.md`.
- **Roo Code / Cline**: Include the tool instructions in custom instructions or project prompt.
- **Google Antigravity**: Loaded automatically via `.agents/skills/comfy2antigravity/SKILL.md`.
- **DeepSeek Harness (`dsh`)**: Loaded as a plugin via `package.json`.
