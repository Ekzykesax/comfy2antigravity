---
name: comfyui-qwen-image
description: Generates high-quality images via local ComfyUI (Qwen-Image-2.1 INT8 + Qwen3-VL 8B NVFP4 + 4-Step Fun-Acc PDD) across all styles, characters, poses, and clothing. Automatically handles character reference images, autogrow slot mapping (images.image_1), separation-of-concerns prompt engineering, anatomical stability, and workspace organization under ComfyUI生图成果/.
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
- **核心模型组合（8GB显存优化热加载）**：
  - Diffusion: `NoctQ_V4_int8_convrot.safetensors` (NoctQ V4 终极结构与微观画质特化主模型，默认唯一主力)
  - LoRA: `none` (NoctQ V4 本身线条与结构特征极致逼真，不叠加多余 LoRA 以保持画面纯粹)
  - Text/Vision Encoder: `qwen3vl_8b_nvfp4.safetensors`
  - VAE: `qwen_image_2.1_vae_bf16.safetensors`
  - 核心采样器: **★ Viggle Turbo 8 步黄金配置 ★** (`Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors` + `KSampler` Euler/Simple, Steps: 8, CFG: 1.0。耗时仅 48 秒，微观去噪轨迹完全收敛，画质与速度的终极平衡点)

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

### 5. 全自动归档与呈现 (Workspace & Artifact Integration)
- 生成完毕后，自动复制生成的图片至：
  1. `<WorkspaceDir>\ComfyUI生图成果\生成的图片\`
  2. `<appDataDir>\brain\<conversation-id>\`
- 注册为 Artifact，并在 carousel 轮播组件中直观展示给用户。

### 6. 服务离线自愈与静默自启 (Auto-Start Mechanism)
- **零干预自动拉起**：每次发起生图前，脚本自动探测 `http://127.0.0.1:8188/system_stats`。
- **自动恢复**：若 ComfyUI 处于未开启状态，自动调用 `scripts/start_comfyui.ps1`，静默唤醒本地 Python 后端（或 Comfy Desktop 客户端），等待就绪后无缝衔接生图流程，无需人工手动查找和开启程序。

### 7. 参考图极速预缩放与空间零冗余 (Auto-Scaling & Disk Saving)
- **毫秒级预压缩**：参考图在送入 ComfyUI 视觉通道前，自动化脚本自动以高质量双三次插值将长边压缩至 `1024` 像素以内。
- **磁盘轻量化**：仅保存优化后的参考图至 `ComfyUI/input/` 与 `ComfyUI生图成果/参考图/`，彻底替换大文件，杜绝冗余存储。
- **净提速收益**：将 Qwen3-VL 的视觉 Token 数量缩减约 80%，节省 4~6 秒的显存搬运与多模态计算时间。

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
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfyui-qwen-image\scripts\generate.ps1" `
  -Prompt "全新的画面与构图：画面中的角色长相、五官、发型与画风严格与图1保持高度一致。全新的姿势与场景：落地窗前背影站姿回眸写真..." `
  -RefImage "anon_ref.png" `
  -Prefix "Viggle8-Anon-Standing" `
  -Width 896 `
  -Height 1152
```

### 2. GGUF 专属管线 (GGUF Q4_K 高精度量化文本编码器 + NoctQ V4 + Viggle 8 步)
```powershell
powershell -ExecutionPolicy Bypass -File ".agents\skills\comfyui-qwen-image\scripts\generate_gguf.ps1" `
  -Prompt "大师级二次元舞台演出概念画，光影层次丰富..." `
  -GgufClip "Qwen-Image-2.1-Turbo-AD-Q4_K.gguf" `
  -VisionSource "qwen3vl_8b_nvfp4.safetensors" `
  -Prefix "GGUF-Q4K-Artistic" `
  -Width 896 `
  -Height 1152
```

无参考图时省略 `-RefImage` 参数即可。
