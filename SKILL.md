---
name: comfy2antigravity
description: Generates and edits high-quality images via local ComfyUI (NoctQ V4 int8 + Qwen3-VL 8B NVFP4). Supports direct text-to-image (generate.ps1, Viggle Turbo 8 steps), character reference generation, and universal high-fidelity image editing (edit_image.ps1, native 25 steps, no turbo LoRA, 1:1 background/face anchor for outfits, hairstyles, poses, props, inpainting). Automatically handles autogrow slot mapping (images.image_1/2), anatomical stability, and workspace organization under ComfyUI生图成果/.
---

# ComfyUI Qwen-Image 通用生图工作流技能

本技能提供基于本地 ComfyUI 的**全品类高保真图像生成与迭代工作流**。适用于动漫插画、真人写实写真、二次元角色立绘、游戏CG、科幻机能、场景概念设计等各类生图任务。

---

## 核心硬件与模型环境参数

- **ComfyUI 服务端地址**：`http://127.0.0.1:8188` (可通过 `-ComfyHost` 指定)
- **ComfyUI 根目录**：自动探测或配置 `$env:COMFYUI_ROOT` (默认兼容 `F:\comfyui\ComfyUI\ComfyUI\` 及主流便携包路径)
  - 输入参考图目录：`<ComfyRootDir>/input/`
  - 生成图片输出目录：`<ComfyRootDir>/output/`
- **工作区成果归档目录**：`<当前工作区>/ComfyUI生图成果/` (可通过 `-WorkspaceDir` 指定)
  - `生成的图片/`：产出图最终归档
  - `参考图/`：官方素材与参考卡面归档
  - `配置与工作流/`：执行脚本与工作流 JSON
- **核心模型组合与 Hugging Face 官方/社区下载地址（8GB显存优化）**：
  - Diffusion: `NoctQ_V4_int8_convrot.safetensors` -> [Noctaluna/Noct-Q-Uncensored-Qwen-Image-2.1](https://huggingface.co/Noctaluna/Noct-Q-Uncensored-Qwen-Image-2.1) (结构与微观画质特化主模型)
  - LoRA: `Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors` -> [Viggle/Qwen-Image-2.1-viggle-turbo](https://huggingface.co/Viggle/Qwen-Image-2.1-viggle-turbo) (8步极速黄金去噪加速)
  - Text/Vision Encoder: `qwen3vl_8b_nvfp4.safetensors` -> [Comfy-Org/Qwen3-VL](https://huggingface.co/Comfy-Org/Qwen3-VL) (NVFP4 省显存多模态编码器)
  - VAE: `qwen_image_2.1_vae_bf16.safetensors` -> [Comfy-Org/Qwen-Image-2.1](https://huggingface.co/Comfy-Org/Qwen-Image-2.1) (官方 BF16 VAE)
  - 核心采样器:
    - **直接文生图 / 参考图生图**：**★ Viggle Turbo 8 步黄金配置 ★** (`Euler / Simple`, Steps: 8, CFG: 1.0。耗时约 42 秒，微观去噪轨迹完全收敛，兼顾极速与构图创作)。
    - **高保真图像编辑**：**★ 官方原生 25 步纯净配置 ★** (`Euler / Simple`, Steps: 25, CFG: 1.0。**严禁使用加速 LoRA**，`resolution = 0` 继承原图比例，潜空间直承原图 Latent，实现背景与五官 1:1 物理锚定)。

---

## 工作流五大铁律

### 1. 特定角色生图规则 (Character Consistency)
- **拒绝脑补盲画**：基础大模型对具体特定二次元角色（如丰川祥子、千早爱音）、VTuber、科技娘（如 DeepSeek娘、Gemini娘）无法单凭提示词准确还原。
- **自动检索并挂载参考图**：
  1. 检索并获取该角色的官方高清立绘/透明卡面，优先选择背景干净、发型五官特征完整的图片；
  2. 存入 ComfyUI `input/` 目录，并备份至 `ComfyUI生图成果/参考图/`；
  3. 工作流中添加 `LoadImage` 节点，连入 `TextEncodeQwenImage21`。

### 2. Autogrow 槽位协议 (Critical Technical Rule)
- 在 ComfyUI API 提交字典中，`TextEncodeQwenImage21` 的多模态输入必须严格使用子键名：
  ```json
  "images.image_1": ["<LoadImage_Node_ID>", 0]
  ```
- **严禁**直接将 Node ID 数组赋值给 `"images"`，否则会引发 PyTorch 张量布尔值歧义异常（`Boolean value of Tensor with more than one value is ambiguous`）。

### 3. 提示词关注点分离法则 (Separation of Concerns)
- **有参考图时**：
  - 文本提示词中**绝对不要**重复描述角色的固有外貌细节（如发色、瞳色、五官）。
  - **统一定式前缀**：
    > `全新的画面与构图：画面中的角色长相、五官与发型严格与图1保持高度一致。`
  - **表情与神态完全自由控制**：表情不受参考图神态约束，可由文本提示词自由指挥（如灿烂微笑、慵懒微醺、害羞灵动、冷艳等）。
  - **后续描述 100% 聚焦于全新内容**：全新表情神态、全新的姿态动作、机位景别、全新穿搭（如舞台礼服/日常制服/运动穿搭）、场景背景、环境光影。
- **无参考图时（原创角色/场景）**：
  - 完整描述主体特征、构图、动作与光影。

### 4. 姿态稳定性与解剖学生理防崩 (Anatomy Stability)
- **避免矛盾视角**：输入正面参考卡面时，避免要求“正面参考图 + 180°极限扭转侧卧”，易诱发脊柱断裂与四肢畸变。
- **推荐高稳定性构图**：
  - **背影站姿回眸**：身体挺拔笔直，展现背部、腰臀与腿部自然线条，肩部微转回眸；
  - **俯卧/端坐**：肢体顺势摆放，四肢自然支撑；
  - **立绘正面/微侧半身**：视线与躯干夹角自然（小于 45°）。
- **通用负向防崩词库**：
  > `(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation`

### 5. 聊天框直发与全端呈现铁律 (Direct In-Chat Delivery & Multi-Platform Sync)
- **聊天框大图直出（强制铁律）**：
  - 每次生图质检通过后，**必须直接在对话回复的 Markdown 正文中使用图片语法 `![alt](file:///...)` 将成图直发至聊天框**，确保用户在当前对话气泡中一眼直观看到完整高清大图。
  - **严禁仅提供文字超链接、代码块或仅收录至 Artifact 文件中而不在聊天框直出大图**。
- **全端与手机端 (Remote Studio) 沉浸兼容**：
  - 必须同时完美兼容桌面端 IDE 与移动端/手机端浏览器（Antigravity Remote Studio）。
  - 聊天框内直发的图片在手机端已实现自动解析与全屏 Lightbox 交互，支持轻触放大与滑动审视。
- **全自动本地归档**：
  - 生成完毕后，脚本自动将成品与参考图归类归档至 `<WorkspaceDir>\ComfyUI生图成果\生成的图片\` 及 `<appDataDir>\brain\<conversation-id>\`。

### 6. 服务离线自愈与静默自启 (Auto-Start Mechanism)
- **零干预自动拉起**：每次发起生图前，脚本自动探测 `http://127.0.0.1:8188/system_stats`。
- **自动恢复**：若 ComfyUI 处于未开启状态，自动调用 `scripts/start_comfyui.ps1`，静默唤醒本地 Python 后端（或 Comfy Desktop 客户端），等待就绪后无缝衔接生图流程，无需人工手动查找和开启程序。

### 7. 参考图极速预压缩与显存零溢出铁律 (Proactive Compression & Zero VRAM Overflow)
- **主动预压缩（强制执行，严禁直传原图）**：
  - 无论用户上传多大画幅的参考图，送入 ComfyUI 视觉通道前，**必须主动预压缩**：
    - 单图参考：长边严格压缩至 `768` 像素以内（或双三次高质量缩放至 ~50 万像素）；
    - 双图/多图参考：每张参考图长边严格限制在 `512 ~ 768` 像素以内，杜绝多图 Token 叠加。
- **TextEncodeQwenImage21 节点强制参数**：
  - **强制 `resolution = 0`**（保持压缩后的自然尺寸，按 32 像素对齐）。
  - **严禁使用默认值 `resolution = 1024`**：ComfyUI 默认的 1024 会把几十万像素的图反向插值放大到 105 万像素，导致 Token 数量暴涨数倍，将 8GB 显卡直接推向系统共享内存换页降速惩罚！
- **净收益**：
  - 彻底杜绝 8GB 显卡显存溢出（Shared GPU Memory 惩罚）；
  - 单步耗时由 15s 降至 4.0s，25 步生成耗时从 5.5 分钟缩减至 2 分钟整，提速超 60%！

### 8. 自适应构图与动态画幅分辨率 (Adaptive Aspect Ratio)
- 告别千篇一律的固定尺寸，根据具体生图画面的题材与构图需求智能匹配最佳分辨率（总像素稳定在 100 万级最优生成甜点区）：
  - **横向宽幅 / 电影感全景 / 卧姿床榻 (16:9 或 4:3)**：`1344 x 768` 或 `1152 x 896`
  - **修长全身 / 挺拔站姿 / 手机壁纸 (9:16 或 2:3)**：`768 x 1344` 或 `832 x 1216`
  - **经典中景肖像 / 杂志写真 (3:4)**：`896 x 1152`
  - **面部特写 / 社交头像 / 方形唱片 (1:1)**：`1024 x 1024`
- 支持通过 `-AspectRatio auto` 自动从提示词语义推断，或通过 `-Width`/`-Height` 任意指定。

### 9. 多参考图多模态分工协议 (Multi-Reference Routing)
- Qwen-Image 2.1 原生支持多达 16 个视觉参考槽位：
  - **图1（Picture 1，`images.image_1`）**：人物面容、发型与固有生理特征；
  - **图2（Picture 2，`images.image_2`）**：特定服装款式、剪裁版型、特定道具或花纹材质；
- 脚本现已原生支持 `-RefImage` 与 `-RefImage2` 双通道，提示词中通过 `图1`、`图2` 明确指定各自交割的视觉维度，实现“指定人物穿指定特定服饰”的超强组合能力。

### 10. 成品质检与自愈重绘闭环 (Self-Inspection & Auto-Redraw Loop)
- **严格自检**：每次生成图片后，Agent 必须主动调用 `view_file` 审视大图细节；
- **核心审视点**：
  1. **手部与十指**：严格核查左右手手指数量（必须为 5 指），手腕与手指关节是否畸变、粘连或多指；
  2. **面部与眼神**：核查眼神光与微表情是否自然生动，坚决杜绝死鱼眼、假面呆滞感；
  3. **身体解剖轴线**：核查四肢、脊柱与比例是否自然流畅。
- **自动自愈清理**：若发现手部、面部或肢体出现明显崩坏畸变，**必须第一时间自动删除缺陷废图**，针对性调整姿态描述与负向词，重新执行渲染，直至产出合格成品后再呈现给用户。

---

## 快速调用指南 (Quick Start)

### 1. 默认旗舰管线 (NVFP4 + Viggle 8 步)
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\generate.ps1" `
  -Prompt "全新的画面与构图：画面中的角色长相、五官、发型与画风严格与图1保持高度一致。全新的姿势与场景：落地窗前背影站姿回眸写真..." `
  -RefImage "anon_ref.png" `
  -Prefix "Viggle8-Anon-Standing" `
  -Width 896 `
  -Height 1152
```

### 2. GGUF 专属管线 (GGUF Q4_K 高精度量化文本编码器 + NoctQ V4 + Viggle 8 步)
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\generate_gguf.ps1" `
  -Prompt "大师级二次元舞台演出概念画，光影层次丰富..." `
  -GgufClip "Qwen-Image-2.1-Turbo-AD-Q4_K.gguf" `
  -VisionSource "qwen3vl_8b_nvfp4.safetensors" `
  -Prefix "GGUF-Q4K-Artistic" `
  -Width 896 `
  -Height 1152
```

### 3. 通用自定义工作流 JSON 调用 (支持 SDXL / Flux / 任意自定义模型)
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\run_workflow.ps1" `
  -WorkflowPath "path/to/your_workflow_api.json" `
  -Prompt "未来科幻概念插画，高精细节..."
```

### 4. 通用高保真图像编辑管线 (全功能指令编辑，官方纯净原生 25 步)
支持换装、改发型、调表情、变姿势、增减环境道具、环境风格置换等任意自然语言指令编辑，严格 1:1 锚定未修改区域。

#### 示例 A：换装与服饰款式替换
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\edit_image.ps1" `
  -Image "photo.jpg" `
  -Prompt "把人物的日常便服换成优雅的黑色吊带晚礼服，佩戴珍珠项链，发型与背景环境严格保持不变"
```

#### 示例 B：双图精准指定换装 (图1人物 + 图2服装参考)
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\edit_image.ps1" `
  -Image "person.jpg" `
  -SecondImage "dress_design.png" `
  -Prompt "将图1中人物的衣服精准替换为图2中的服装款式与材质，人物长相五官与原图背景严格不变"
```

#### 示例 C：发型、表情与氛围微调
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\edit_image.ps1" `
  -Image "portrait.jpg" `
  -Prompt "将人物发型改为棕色波浪长卷发，表情改为温柔浅笑，微风吹拂发丝，衣服与背景完全不变"
```

#### 示例 D：背景光影与季节氛围置换
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfy2antigravity\scripts\edit_image.ps1" `
  -Image "landscape_portrait.jpg" `
  -Prompt "将背景环境调整为静谧的黄昏落日时分，晚霞金光洒落在人物发梢与肩头，人物衣着与五官完全保持一致"
```

> **底层架构注记**：通用图像编辑管线**绝对不使用加速 LoRA**，采样器直连纯净 UNet 官方原生 25 步，`resolution = 0` 严格继承原图尺寸比例，潜空间直承原图 Latent，实现未修改区域（五官、发型、背景建筑、光影）的像素级物理锚定。

> 💡 **跨平台与多 Agent 兼容**：所有脚本均提供对等的纯标准库跨平台 Python CLI（`scripts/generate.py`、`scripts/edit_image.py`），原生适配 **DeepSeek Harness (`dsh`)** 与 **OpenAI Codex** 环境，规范详见 [`AGENTS.md`](AGENTS.md)。




