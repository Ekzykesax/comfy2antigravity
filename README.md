# comfy2antigravity

ComfyUI 本地图像生成与高保真编辑插件，专为 **Antigravity**、**DeepSeek Harness (`dsh`)** 与 **OpenAI Codex** 设计。

[![Antigravity Skill](https://img.shields.io/badge/Antigravity-Skill-blue.svg)](https://github.com/Ekzykesax/comfy2antigravity)
[![DeepSeek-Harness Compatible](https://img.shields.io/badge/DeepSeek__Harness-Compatible-purple.svg)]()
[![OpenAI-Codex Compatible](https://img.shields.io/badge/OpenAI__Codex-Compatible-black.svg)]()
[![ComfyUI-Zero_Config](https://img.shields.io/badge/ComfyUI-Zero__Config-success.svg)]()
[![License-Apache_2.0](https://img.shields.io/badge/License-Apache_2.0-yellowgreen.svg)](LICENSE)

将强大的本地 ComfyUI 图像能力封装为**零操作门槛**的智能体体验：**免连线、免调参、跨 Agent 通用**。用户与 Agent 均无需面对 ComfyUI 繁琐的画布节点，通过标准自然语言指令或标准 Python CLI 即可完成服务检测、多模态槽位映射、采样渲染与成果归档。

既内置了开箱即用的高保真文生图、参考图生图与通用图像编辑管线（基于 Qwen-Image 2.1 架构），也支持无缝执行任意自定义导出的 ComfyUI API JSON 工作流。

<p align="center">
  <img src="assets/demo_ui.png" alt="工作流演示" width="800">
</p>

---

## 功能特性

1. **零 ComfyUI 操作门槛（免连线、免调参）**：
   - 传统 ComfyUI 复杂的连线网络、节点组合与参数调度全部由底层自动化脚本接管；
   - 自动处理多模态张量规范（如 `images.image_1` / `images.image_2` 槽位映射），杜绝常见布尔歧义报错，用户侧仅需自然语言交互。
2. **多主流 Agent 原生兼容**：
   - **Antigravity**：通过 `SKILL.md` 识别，作为原生 Agent 技能载入；
   - **DeepSeek Harness (`dsh`)**：内置 `package.json` 插件清单与 `dsh` 工具定义，支持无缝插件化加载；
   - **OpenAI Codex / Code Agents**：提供纯标准库 Python CLI（`generate.py` / `edit_image.py`）与 `AGENTS.md` 规范，跨平台零依赖直接执行。
3. **多模态参考图一致性**：支持单图或双图参考输入，当提示词指定特定角色或物品时，支持自动检索并接入参考图，结合关注点分离原则保持人物特征一致。
4. **双采样方案按需分工**：
   - **文生图 / 参考生图（构图创作）**：采用 Viggle Turbo 8 步加速（Euler / Simple, CFG 1.0），空 Latent 随机扩散，约 40 秒快速出图。
   - **通用图像编辑（高保真原图锚定）**：采用官方原生 25 步采样，不加载加速 LoRA，`resolution = 0` 继承原图尺寸，直承原图 Latent，实现未修改区域（背景、光影、五官）1:1 锚定。
5. **服务状态检测与自启**：执行生图前自动探测 ComfyUI API 连通性，若未启动则自动后台拉起，无需手动开启终端。
6. **图像预处理与自动归档**：输入参考图自动预缩放至长边 1024 像素内减少显存占用；生成结果自动归档至工作区 `ComfyUI生图成果/` 目录。

---

## 快速上手

### 1. 运行本地 ComfyUI
确保本地 ComfyUI 正常运行于 `http://127.0.0.1:8188`（默认地址）。如未运行，脚本会在调用时尝试自动拉起。

### 2. 准备模型文件
将所需模型放置于 ComfyUI 对应目录下：

| 模型类型 | 推荐模型文件 | 存放路径 | 来源链接 |
| :--- | :--- | :--- | :--- |
| **Diffusion 主模型** | `NoctQ_V4_int8_convrot.safetensors` | `ComfyUI/models/diffusion_models/` | [Noct-Q Qwen-Image 2.1](https://huggingface.co/Noctaluna/Noct-Q-Uncensored-Qwen-Image-2.1) |
| **加速 LoRA (可选)** | `Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors` | `ComfyUI/models/loras/` | [Viggle Turbo](https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo) |
| **多模态编码器** | `qwen3vl_8b_nvfp4.safetensors` | `ComfyUI/models/clip/` | [Qwen3-VL](https://huggingface.co/Comfy-Org/Qwen3-VL) |
| **VAE 编解码器** | `qwen_image_2.1_vae_bf16.safetensors` | `ComfyUI/models/vae/` | [Qwen-Image-2.1 VAE](https://huggingface.co/Comfy-Org/Qwen-Image-2.1) |

> 提示：若使用其他文件名，可在调用时通过 `--unet` / `-Unet` 或 `--lora` / `-Lora` 参数指定。

### 3. 安装到 Agent 环境

#### 在 Antigravity 中安装：
```bash
git clone https://github.com/Ekzykesax/comfy2antigravity.git .agents/skills/comfy2antigravity
```

#### 在 DeepSeek Harness (`dsh`) 中安装：
克隆至插件目录或通过 dsh 载入：
```bash
dsh plugin add https://github.com/Ekzykesax/comfy2antigravity.git
```

#### 在 OpenAI Codex 或通用环境中使用：
直接克隆仓库，运行 Python 脚本即可（零额外 pip 依赖）：
```bash
git clone https://github.com/Ekzykesax/comfy2antigravity.git
```

---

## 使用示例

安装后，可直接在对话中通过自然语言请求 Agent 执行，或在终端通过 Python / PowerShell CLI 运行。

### 1. 纯文本生图
- **自然语言**：“生成一张赛博朋克雨夜街道的概念插画，霓虹灯倒映在积水里，写实光影。”
- **Python CLI (跨平台 / DeepSeek Harness / Codex)**：
  ```bash
  python scripts/generate.py --prompt "赛博朋克雨夜街道，霓虹灯倒影..." --width 1344 --height 768
  ```
- **PowerShell (Windows)**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File "scripts/generate.ps1" -Prompt "赛博朋克雨夜街道，霓虹灯倒影..." -Width 1344 -Height 768
  ```

### 2. 参考图生图（角色 / 画风保持）
- **自然语言**：“参考 input/sakiko_ref.png 中的人物，生成一张在钢琴前弹奏的插画，保持人物特征与画风。”
- **Python CLI (跨平台 / DeepSeek Harness / Codex)**：
  ```bash
  python scripts/generate.py --ref-image "input/sakiko_ref.png" --prompt "角色在黑色大三角钢琴前弹奏，室内暖光..."
  ```
- **PowerShell (Windows)**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File "scripts/generate.ps1" -RefImage "input/sakiko_ref.png" -Prompt "角色在黑色大三角钢琴前弹奏，室内暖光..."
  ```

### 3. 通用高保真图像编辑（换装 / 调姿 / 换景）
图像编辑管线不使用加速 LoRA，基于原生 25 步与原图 Latent 锚定，只对指定区域做修改，未指定区域严格保持不变。

- **单图自然语言指令编辑**：
  - **自然语言**：“把 photo.jpg 中人物的日常便服换成黑色晚礼服，发型改成微卷长发，背景和五官保持不变。”
  - **Python CLI (跨平台 / DeepSeek Harness / Codex)**：
    ```bash
    python scripts/edit_image.py --image "photo.jpg" --prompt "将人物的日常便服换成黑色吊带晚礼服，发型改成微卷长发，背景和五官严格保持不变"
    ```
  - **PowerShell (Windows)**：
    ```powershell
    powershell -ExecutionPolicy Bypass -File "scripts/edit_image.ps1" -Image "photo.jpg" -Prompt "将人物的日常便服换成黑色吊带晚礼服，发型改成微卷长发，背景和五官严格保持不变"
    ```

- **双图换装（跨图指定款式换装）**：
  - **自然语言**：“把 person.jpg 中人物的衣服换成 dress.png 中的款式与材质，保持人物五官与背景不变。”
  - **Python CLI (跨平台 / DeepSeek Harness / Codex)**：
    ```bash
    python scripts/edit_image.py --image "person.jpg" --second-image "dress.png" --prompt "将图1中人物的服装替换为图2中的款式与材质，人物长相与背景保持不变"
    ```

---

## 进阶：自定义模型与工作流

1. **指定其他 Diffusion 模型**：
   ```bash
   python scripts/generate.py --prompt "..." --unet "other_model.safetensors"
   ```

2. **执行任意 ComfyUI 导出的 API JSON**：
   在 ComfyUI Web 界面点击 **Save (API Format)** 导出 JSON，然后通过以下方式执行：
   ```powershell
   powershell -ExecutionPolicy Bypass -File "scripts/run_workflow.ps1" -WorkflowPath "path/to/custom_workflow_api.json" -Prompt "自定义提示词..."
   ```

---

## 文件结构

```text
comfy2antigravity/
├── SKILL.md                 # Antigravity 智能体技能主配置文件
├── AGENTS.md                # DeepSeek Harness / Codex / 通用 Agent 接口调用指南
├── package.json             # DeepSeek Harness (dsh) 插件清单与工具声明
├── plugin.json              # Antigravity 插件元数据清单
├── README.md                # 统一使用说明文档
├── LICENSE                  # Apache 2.0 开源协议
├── workflows/
│   └── 图像编辑_原生25步_NoctQ.json  # ComfyUI GUI 工作流 (原生25步纯净编辑)
└── scripts/
    ├── generate.py          # 跨平台 Python 文生图 / 参考图生图 (DeepSeek / Codex 主力)
    ├── edit_image.py        # 跨平台 Python 通用高保真图像编辑 (DeepSeek / Codex 主力)
    ├── generate.ps1         # Windows PowerShell 文生图 / 参考图生图
    ├── edit_image.ps1       # Windows PowerShell 图像编辑
    ├── generate_gguf.ps1    # GGUF 特化编码器生图脚本
    ├── run_workflow.ps1     # 自定义工作流 API JSON 执行器
    └── start_comfyui.ps1    # 服务状态检测与静默自启脚本
```

---

## 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。
