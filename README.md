# ComfyUI Qwen-Image 生产级全品类高保真生图工作流技能 (Antigravity Skill)

[![Antigravity Skill](https://img.shields.io/badge/Antigravity-Skill-blue.svg)](https://github.com/Ekzykesax/comfyui-qwen-image)
[![Model-NoctQ_V4](https://img.shields.io/badge/Diffusion-NoctQ__V4__INT8-purple.svg)]()
[![Sampler-Viggle_Turbo](https://img.shields.io/badge/Sampler-Viggle__Turbo__8Steps-success.svg)]()
[![License-Apache_2.0](https://img.shields.io/badge/License-Apache_2.0-yellowgreen.svg)](LICENSE)

专为 **Google Antigravity** 与 **ComfyUI 本地后端** 设计的高保真、生产级全自动图像生成与迭代工作流。

基于 **NoctQ V4 (Qwen-Image 2.1 INT8) + Qwen3-VL 8B NVFP4 + Viggle Turbo 8 步黄金去噪配置**，全面覆盖二次元动漫原画、游戏 CG、真人摄影、角色立绘与概念场景设计。

---

## 🌟 核心特性与技术亮点

1. **★ Viggle Turbo 8 步极致收敛 ★**
   - 采用 `Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors` + `Euler / Simple` 黄金组合。
   - 单张 100 万像素出图仅需约 **42~48 秒**，在极致出图速度的同时实现画质与微观解剖线条的绝对收敛。
2. **特定角色一致性 & Autogrow 槽位协议**
   - 严格遵循多模态槽位映射规范，使用 `images.image_1` 连入视觉多模态编码器，彻底避免 PyTorch 张量布尔歧义报错。
   - 配合“关注点分离”提示词定式，自动继承参考图的发型、五官与固有画风，同时保证神态、动作、服装自由受控。
3. **多参考图分工路由 (Multi-Reference Routing)**
   - 原生支持双参考通道（`-RefImage` 与 `-RefImage2`），精准交割“图1定面容特征 + 图2定服饰版型道具”。
4. **服务自愈与零干预唤醒 (Self-Healing Auto-Launch)**
   - 调度脚本每次请求前自动探测 ComfyUI 服务状态，若遇未开启则静默拉起本地 Python 后端或 Comfy Desktop，就绪后无缝恢复执行。
5. **毫秒级参考图自动预压缩 (Auto-Scaling)**
   - 进入多模态视觉通道前，自动以双三次插值将大图等比压缩至 1024 像素内，大幅节省 80% 视觉 Token 与显存搬运耗时。
6. **自适应画幅与动态构图 (Adaptive Aspect Ratio)**
   - 支持智能推断语义匹配黄金比例：宽幅横构图 (16:9 / 4:3)、立绘全身 (9:16 / 2:3)、肖像写真 (3:4)、特写头像 (1:1)。
7. **全自动归档与成品质检闭环**
   - 自动分类归档至 `<工作区>/ComfyUI生图成果/生成的图片/` 与 `参考图/`。

---

## 🛠️ 推荐模型与环境配置

建议将模型放置于 ComfyUI 对应目录：

| 类型 | 推荐模型文件名 | 存放路径 | 说明 |
| :--- | :--- | :--- | :--- |
| **Diffusion 主模型** | `NoctQ_V4_int8_convrot.safetensors` | `ComfyUI/models/diffusion_models/` | 终极解剖特化主力模型 |
| **LoRA 加速器** | `Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors` | `ComfyUI/models/loras/` | Viggle Turbo 4/8步加速 |
| **文本与视觉编码器** | `qwen3vl_8b_nvfp4.safetensors` | `ComfyUI/models/clip/` | NVFP4 多模态编码器 |
| **GGUF 编码器(可选)** | `Qwen-Image-2.1-Turbo-Uncensored-AD-Q4_K.gguf` | `ComfyUI/models/clip/` | 适合深度语义管线 |
| **VAE** | `qwen_image_2.1_vae_bf16.safetensors` | `ComfyUI/models/vae/` | 官方 BF16 VAE |

---

## 📂 仓库目录结构

```text
comfyui-qwen-image/
├── SKILL.md                 # Antigravity 智能体技能主配置文件
├── README.md                # 技能详细指南与快速上手
├── LICENSE                  # 开源协议 (Apache 2.0)
├── plugin.json              # 插件化清单配置文件
└── scripts/
    ├── generate.ps1         # 默认旗舰生图管线 (NVFP4 + Viggle 8 步)
    ├── generate_gguf.ps1    # GGUF 特化编码器生图管线
    └── start_comfyui.ps1    # ComfyUI 离线静默唤醒与就绪探测脚本
```

---

## 🚀 快速上手

### 1. 安装方式

#### 方式 A：作为项目技能引入 (推荐)
直接克隆到您当前项目工作区的 `.agents/skills/` 目录：
```bash
git clone https://github.com/Ekzykesax/comfyui-qwen-image.git .agents/skills/comfyui-qwen-image
```

#### 方式 B：作为全局技能引入
克隆至用户配置目录下，所有项目均可全局调用：
```bash
git clone https://github.com/Ekzykesax/comfyui-qwen-image.git ~/.gemini/config/skills/comfyui-qwen-image
```

### 2. 环境变量配置 (可选)
如果您的 ComfyUI 不在默认盘符路径，可设置环境变量（脚本也会自动扫描常见路径）：
```powershell
$env:COMFYUI_ROOT = "D:\ComfyUI_windows_portable\ComfyUI"
```

### 3. 在 Antigravity 对话中自然语言调用
直接对 AI 智能体说：
> “参考参考图 sakiko_ref.png，画一张丰川祥子在舞台上弹奏三角钢琴的图，MyGO 原画风。”

AI 智能体会自动挂载此技能，完成参数配置、提示词编排、自启后端并提交渲染。

### 4. 手动脚本调用
亦可在 PowerShell 中独立运行生成脚本：
```powershell
powershell -ExecutionPolicy Bypass -File "scripts/generate.ps1" `
  -Prompt "全新的画面与构图：画面中的角色长相、五官、发型与画风严格与图1保持高度一致。全新的姿势与场景：钢琴前优雅侧身演奏..." `
  -RefImage "input/sakiko_ref.png" `
  -Width 1152 `
  -Height 896 `
  -Steps 8
```

---

## 📄 开源许可证

本项目基于 [Apache License 2.0](LICENSE) 开源发布。
