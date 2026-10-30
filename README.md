<p align="right">
  <a href="README_EN.md">English</a> | <b>中文说明</b>
</p>

# comfy2antigravity

> **面向全品类 AI Coding Agent 的 ComfyUI 本地图像生成、高保真编辑与超分技能库**  
> Universal ComfyUI Skill & Toolset for All AI Coding Agents

[![Claude Code Compatible](https://img.shields.io/badge/Claude__Code-Compatible-orange.svg)]()
[![Cursor & Windsurf](https://img.shields.io/badge/Cursor%20%26%20Windsurf-Ready-blue.svg)]()
[![Cline & Roo Code](https://img.shields.io/badge/Cline%20%26%20Roo--Code-Supported-green.svg)]()
[![Antigravity Skill](https://img.shields.io/badge/Antigravity-Skill-blue.svg)](https://github.com/Ekzykesax/comfy2antigravity)
[![DeepSeek-Harness Compatible](https://img.shields.io/badge/DeepSeek__Harness-Compatible-purple.svg)]()
[![OpenAI Codex & Aider](https://img.shields.io/badge/OpenAI__Codex%20%26%20Aider-Ready-black.svg)]()
[![ComfyUI-Zero_Config](https://img.shields.io/badge/ComfyUI-Zero__Config-success.svg)]()
[![License-Apache_2.0](https://img.shields.io/badge/License-Apache_2.0-yellowgreen.svg)](LICENSE)

将强大的本地 ComfyUI 图像创作与编辑能力封装为**零操作门槛**的智能体体验：**免连线、免调参、跨 Agent 全通用**。用户与 Agent 均无需面对 ComfyUI 繁琐的画布节点，通过标准自然语言指令或纯标准库 Python CLI 即可完成服务自检、多模态槽位映射、采样渲染、4K 景深超分与成果分级归档。

既内置了开箱即用的高保真文生图、参考图生图、通用指令图像编辑、二次元实景融合管线（基于 Qwen-Image 2.1 架构），也支持无缝执行任意自定义导出的 ComfyUI API JSON 工作流。

---

## 效果展示 (Showcase)

| 京都岚山渡月桥 (实景融合 / 4K/8K 超分) | 河口湖罗森便利店 (长焦景深 / 4K 超分) |
| :---: | :---: |
| <img src="assets/showcase_togetsukyo_saber.jpg" alt="京都渡月桥 Saber" width="450"> | <img src="assets/showcase_lawson_fuji.jpg" alt="河口湖罗森富士山 Saber" width="450"> |
| 侧逆轮廓光 + 织物阴影体积感 + 背景单反浅景深虚化 | 街景摄影长焦压缩 + 纯正二次元五官无缝融入 |

<p align="center">
  <img src="assets/demo_ui.png" alt="工作流演示" width="800">
</p>

---

## 核心特性

1. **零 ComfyUI 操作门槛（免连线、免调参）**：
   - 传统 ComfyUI 复杂的连线网络、节点组合与参数调度全部由底层自动化脚本接管；
   - 自动处理多模态张量规范（如 `images.image_1` / `images.image_2` 槽位映射），杜绝常见布尔歧义报错，用户侧仅需自然语言交互。
2. **全品类 AI Coding Agent 原生兼容**：
   - **Claude Code**：在项目提示词或 Tool 命令中直调跨平台 Python CLI；
   - **Cursor / Windsurf**：在 `.cursorrules` 或 `.windsurfrules` 中声明，Agent 自动识别并调度；
   - **Roo Code / Cline**：作为 Custom Instructions 载入，赋能生图与指令编辑能力；
   - **Google Antigravity**：通过 `SKILL.md` 原生载入，支持聊天框直出大图与手机端 (Remote Studio) 无缝放大；
   - **DeepSeek Harness (`dsh`)**：内置 `package.json` 插件清单与 `dsh` 工具定义，一键载入；
   - **OpenAI Codex / Aider / OpenCode**：纯标准库 Python 3 脚本（零外部 pip 依赖），输出标准 JSON，跨平台即开即用。
3. **多模态参考图一致性**：支持单图或双图参考输入，当提示词指定特定角色或物品时，支持自动检索并接入参考图，结合关注点分离原则保持人物特征一致。
4. **多管线采样方案按需分工**：
   - **文生图 / 参考生图（构图创作管线）**：采用 Viggle Turbo 8 步加速（Euler / Simple, CFG 1.0），空 Latent 随机噪点扩散，微观去噪轨迹完全收敛，兼顾极速与细节构图；
   - **通用高保真图像编辑（原图锚定管线）**：采用官方原生 25 步纯净采样，**绝对不加载加速 LoRA**，`resolution = 0` 继承原图物理画幅，潜空间直承原图 Latent，实现未修改区域（背景、光影、五官）1:1 像素级物理锚定；
   - **二次元实景融合管线 (2D Anime + Real Photo Blending)**：双垫图机制（图1人物立绘 + 图2实景摄影），原生 25 步采样，继承渡月桥殿堂级黄金范式，油画厚重光影塑造体积感，彻底消除粗重黑边与 3D 塑料感。
5. **4K 景深保真双流超分（Focus-Aware Bokeh Preservation）**：
   - 唯一主力使用 **`4x_foolhardy_Remacri.pth`**，内置双流焦外保真算法；
   - 焦内核心主体（人物五官、发丝、服饰纹理与核心道具）执行 4K 神经级精细超分；
   - 焦外背景（远景、雪原、虚化光斑）通过纯净数学平滑放大，通过高频能量图梯度羽化无缝融合，彻底消除传统超分强行锐化焦外背景产生生硬假噪点的顽疾。
6. **服务状态检测与静默自启**：执行生图前自动探测 ComfyUI API 连通性，若未启动则自动后台唤醒拉起，无需手动开启终端。
7. **图像预处理与成果分级归档**：
   - 输入参考图自动预缩放至长边 768 像素内，大幅降低显存占用并彻底杜绝 GPU 共享显存换页惩罚；
   - 资产统一沉淀至 `ComfyUI生图成果/` 分级目录，业务目录内严格区分 **`全年龄/`** 与 **`NSFW/`**：
     - `成品图/`：**满意成品专库**（4K 极清超分默认代表满意，双流超分后自动直通收录；满意的非 4K 作品亦可一键收录）；
     - `生成的图片/`：日常文生图、图像编辑、实景融合及过程草稿归档；
     - `参考图/`：角色垫图、背景图与官方素材库；
     - `配置与工作流/`：ComfyUI API 工作流配置与调度脚本。

---

## 全主流 Agent 快速集成指南

本技能针对市面上主流 AI 编程助手与智能体环境进行了针对性适配：

### 1. Claude Code (Anthropic)
在项目根目录的 `CLAUDE.md` 或全局指令中引入 `AGENTS.md`：
```markdown
# Image Generation & Editing Tooling
Use the Python scripts under `scripts/` to generate, edit, or upscale images via local ComfyUI.
Refer to `AGENTS.md` for standard CLI flags and JSON outputs.
```

### 2. Cursor / Windsurf
在 `.cursorrules` 或 `.windsurfrules` 中添加以下规则：
```markdown
When the user asks to generate, edit, upscale, or blend images:
1. Always use `python scripts/generate.py`, `python scripts/edit_image.py`, `python scripts/blend_anime_real.py`, or `python scripts/upscale_image.py`.
2. Parse the output JSON to find the generated image path under `ComfyUI生图成果/`.
3. Read `AGENTS.md` for complete CLI argument specifications.
```

### 3. Roo Code / Cline (VS Code)
在 Custom Instructions 中导入 `AGENTS.md` 内容，赋能智能体通过执行终端命令完成全自动生图与图像微调。

### 4. Google Antigravity
克隆至技能目录，智能体将通过 `SKILL.md` 自动识别为原生技能：
```bash
git clone https://github.com/Ekzykesax/comfy2antigravity.git .agents/skills/comfy2antigravity
```

### 5. DeepSeek Harness (`dsh`)
通过 dsh 插件命令一键安装：
```bash
dsh plugin add https://github.com/Ekzykesax/comfy2antigravity.git
```

### 6. OpenAI Codex / Aider / OpenCode / 终端环境
直接克隆仓库，通过标准 Python 3 直接运行（零额外 pip 依赖）：
```bash
git clone https://github.com/Ekzykesax/comfy2antigravity.git
```

---

## 准备模型文件

确保本地 ComfyUI 运行于 `http://127.0.0.1:8188`（默认地址）。将所需模型放置于 ComfyUI 对应目录下：

| 模型类型 | 推荐模型文件 | 存放路径 | 来源链接 |
| :--- | :--- | :--- | :--- |
| **Diffusion 主模型** | `NoctQ_V4_int8_convrot.safetensors` | `ComfyUI/models/diffusion_models/` | [Noct-Q Qwen-Image 2.1](https://huggingface.co/Noctaluna/Noct-Q-Uncensored-Qwen-Image-2.1) |
| **加速 LoRA (可选)** | `Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors` | `ComfyUI/models/loras/` | [Viggle Turbo](https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo) |
| **多模态编码器** | `qwen3vl_8b_nvfp4.safetensors` | `ComfyUI/models/clip/` | [Qwen3-VL](https://huggingface.co/Comfy-Org/Qwen3-VL) |
| **VAE 编解码器** | `qwen_image_2.1_vae_bf16.safetensors` | `ComfyUI/models/vae/` | [Qwen-Image-2.1 VAE](https://huggingface.co/Comfy-Org/Qwen-Image-2.1) |
| **4K 极清超分模型** | `4x_foolhardy_Remacri.pth` | `ComfyUI/models/upscale_models/` | [4x_foolhardy_Remacri](https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri) |

> 提示：若使用其他模型文件名，可在调用时通过 `--unet` / `-Unet` 或 `--lora` / `-Lora` 参数指定。

---

## 使用示例

安装后，可直接在对话中通过自然语言请求 Agent 执行，或在终端通过 Python / PowerShell CLI 运行。

### 1. 纯文本生图
- **自然语言**：“生成一张赛博朋克雨夜街道的概念插画，霓虹灯倒映在积水里，写实光影。”
- **Python CLI (跨平台 / Claude Code / Cursor / Codex)**：
  ```bash
  python scripts/generate.py --prompt "赛博朋克雨夜街道，霓虹灯倒影..." --width 1344 --height 768
  ```
- **PowerShell (Windows)**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File "scripts/generate.ps1" -Prompt "赛博朋克雨夜街道，霓虹灯倒影..." -Width 1344 -Height 768
  ```

### 2. 参考图生图（角色 / 画风保持）
- **自然语言**：“参考 input/sakiko_ref.png 中的人物，生成一张在钢琴前弹奏的插画，保持人物特征与画风。”
- **Python CLI (跨平台 / 通用 Agent)**：
  ```bash
  python scripts/generate.py --ref-image "input/sakiko_ref.png" --prompt "角色在黑色大三角钢琴前弹奏，室内暖光..."
  ```
- **PowerShell (Windows)**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File "scripts/generate.ps1" -RefImage "input/sakiko_ref.png" -Prompt "角色在黑色大三角钢琴前弹奏，室内暖光..."
  ```

### 3. 通用高保真图像编辑（换装 / 调姿 / 换景）
图像编辑管线不使用加速 LoRA，基于原生 25 步与原图 Latent 锚定，只对指定区域做修改，未修改区域 1:1 严格保持不变。

- **单图自然语言指令编辑**：
  ```bash
  python scripts/edit_image.py --image "photo.jpg" --prompt "将人物的日常便服换成黑色吊带晚礼服，发型改成微卷长发，背景和五官严格保持不变"
  ```
- **双图换装（跨图指定款式换装）**：
  ```bash
  python scripts/edit_image.py --image "person.jpg" --second-image "dress.png" --prompt "将图1中人物的服装替换为图2中的款式与材质，人物长相与背景保持不变"
  ```

### 4. 二次元角色实景融合 (2D Anime + Real Photo Blending)
适用于“真实照片背景 + 二次元人物”的殿堂级融合创作，人物具有清澈纯正动漫五官与油画般立体光影，背景呈现单反自然光学散景。

- **自然语言**：“把 saber_ref.png 中的角色自然融入到 tokyo_night.jpg 的真实东京夜景中，保留油画般厚重光影。”
- **Python CLI (跨平台 / 通用 Agent)**：
  ```bash
  python scripts/blend_anime_real.py --char-ref "saber_ref.png" --bg-ref "tokyo_night.jpg" --resolution "3M"
  ```
- **PowerShell (Windows)**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File "scripts/blend_anime_real.ps1" -CharRef "saber_ref.png" -BgRef "tokyo_night.jpg" -Resolution "3M"
  ```

### 5. 4K/8K 景深保真极清超分（Remacri + Bokeh Preservation）
解决常规超分无脑锐化背景虚化的硬伤，主体保持 4K/8K 极清，背景保持大光圈自然光学奶油虚化。

- **自然语言**：“把生成的图片超分到 4K（或 8K），保留自然的背景景深虚化。”
- **Python CLI (跨平台 / 通用 Agent)**：
  ```bash
  # 4K 超分
  python scripts/upscale_image.py --image "output/portrait.png" --target_width 3840

  # 8K 极限超分 (3300万像素)
  python scripts/upscale_image.py --image "output/portrait.png" --target_width 7680
  ```
- **PowerShell (Windows)**：
  ```powershell
  powershell -ExecutionPolicy Bypass -File "scripts/upscale_image.ps1" -Image "output/portrait.png" -Width 3840
  ```

---

## 文件结构

```text
comfy2antigravity/
├── README.md                # 中文版使用说明文档 (含全 Agent 适配指南)
├── README_EN.md             # 英文版使用说明文档 (English Documentation)
├── AGENTS.md                # 全主流 AI Coding Agent 通用调用规范与接口指南
├── SKILL.md                 # Antigravity 智能体技能主配置文件
├── package.json             # DeepSeek Harness (dsh) 插件清单与通用 Agent 工具声明
├── plugin.json              # Antigravity 插件元数据清单
├── LICENSE                  # Apache 2.0 开源协议
├── workflows/
│   ├── 图像编辑_原生25步_NoctQ.json        # ComfyUI GUI 工作流 (原生25步纯净编辑)
│   └── 二次元实景融合_原生25步_NoctQ.json  # ComfyUI GUI 工作流 (渡月桥殿堂级双垫图融合)
└── scripts/
    ├── generate.py          # 跨平台 Python 文生图 / 参考图生图 (通用 Agent 主力)
    ├── edit_image.py        # 跨平台 Python 通用高保真图像编辑 (通用 Agent 主力)
    ├── blend_anime_real.py  # 跨平台 Python 二次元角色实景融合 (通用 Agent 主力)
    ├── upscale_image.py     # 跨平台 Python 4K 景深保真双流超分 (Remacri + Bokeh)
    ├── save_finished.py     # 跨平台 Python 满意作品/成品一键归档
    ├── generate.ps1         # Windows PowerShell 文生图 / 参考图生图
    ├── edit_image.ps1       # Windows PowerShell 图像编辑
    ├── blend_anime_real.ps1 # Windows PowerShell 二次元角色实景融合
    ├── upscale_image.ps1    # Windows PowerShell 4K 景深保真双流超分
    ├── save_finished.ps1    # Windows PowerShell 满意作品一键归档
    ├── generate_gguf.ps1    # GGUF 特化编码器生图脚本
    ├── run_workflow.ps1     # 自定义工作流 API JSON 执行器
    └── start_comfyui.ps1    # 服务状态检测与静默自启脚本
```

---

## 许可证

本项目基于 [Apache License 2.0](LICENSE) 开源。
