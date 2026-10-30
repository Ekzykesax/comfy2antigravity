param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias("RefImage", "InputImage")]
    [string]$Image,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Prompt,

    [Parameter(Mandatory = $false)]
    [Alias("RefImage2", "StyleRef")]
    [string]$SecondImage = "",

    [Parameter(Mandatory = $false)]
    [string]$NegativePrompt = "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation",

    [Parameter(Mandatory = $false)]
    [string]$Prefix = "NoctQ-ImageEdit",

    [Parameter(Mandatory = $false)]
    [int]$Steps = 25,

    [Parameter(Mandatory = $false)]
    [double]$Cfg = 1.0,

    [Parameter(Mandatory = $false)]
    [string]$SamplerName = "euler",

    [Parameter(Mandatory = $false)]
    [string]$Scheduler = "simple",

    [Parameter(Mandatory = $false)]
    [int]$Resolution = 0, # 0 = 原生零缩放，完全保留原图高宽比与像素（对齐32倍数）

    [Parameter(Mandatory = $false)]
    [long]$Seed = 0,

    [Parameter(Mandatory = $false)]
    [string]$ComfyHost = "http://127.0.0.1:8188",

    [Parameter(Mandatory = $false)]
    [string]$ComfyRootDir = "F:\comfyui\ComfyUI",

    [Parameter(Mandatory = $false)]
    [string]$Unet = "NoctQ_V4_int8_convrot.safetensors",

    [Parameter(Mandatory = $false)]
    [string]$Clip = "qwen3vl_8b_nvfp4.safetensors",

    [Parameter(Mandatory = $false)]
    [string]$Vae = "qwen_image_2.1_vae_bf16.safetensors",

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceDir = "",

    [Parameter(Mandatory = $false)]
    [string]$Lora = "auto",

    [Parameter(Mandatory = $false)]
    [double]$LoraStrength = 0.8,

    [Parameter(Mandatory = $false)]
    [switch]$NSFW
)

$ErrorActionPreference = "Stop"

# Auto-detect ComfyRootDir
if (-not (Test-Path $ComfyRootDir)) {
    if ($env:COMFYUI_ROOT -and (Test-Path $env:COMFYUI_ROOT)) {
        $ComfyRootDir = $env:COMFYUI_ROOT
    } else {
        $candidates = @("F:\comfyui\ComfyUI", "C:\ComfyUI_windows_portable", "D:\ComfyUI_windows_portable", "C:\ComfyUI", "D:\ComfyUI")
        foreach ($c in $candidates) {
            if (Test-Path $c) { $ComfyRootDir = $c; break }
        }
    }
}

$defaultWorkspaceFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("Q29tZnlVSeeUn+WbvuaIkOaenA==")) # "ComfyUI生图成果"
$outputFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("55Sf5oiQ55qE5Zu+54mH")) # "生成的图片"

if (-not $WorkspaceDir -or $WorkspaceDir.Trim() -eq "") {
    if ($env:COMFY_WORKSPACE_DIR -and (Test-Path $env:COMFY_WORKSPACE_DIR)) {
        $WorkspaceDir = $env:COMFY_WORKSPACE_DIR
    } else {
        $WorkspaceDir = Join-Path $PWD.Path $defaultWorkspaceFolderName
    }
}

# 1. 检查 ComfyUI 服务状态（离线则自动拉起）
$isOnline = $false
try {
    $stats = Invoke-RestMethod -Uri "$ComfyHost/system_stats" -Method Get -TimeoutSec 3 -ErrorAction Stop
    $isOnline = $true
    Write-Host "[ImageEdit] ComfyUI server is online at $ComfyHost"
} catch {
    Write-Host "[ImageEdit] Server offline. Launching auto-start..."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $starterScript = Join-Path $scriptDir "start_comfyui.ps1"
    if (Test-Path $starterScript) {
        $started = & $starterScript -ComfyHost $ComfyHost -ComfyRootDir $ComfyRootDir
        if ($started -eq $true) { $isOnline = $true }
    }
}

if (-not $isOnline) {
    Write-Error "[ImageEdit] Could not connect to ComfyUI."
    exit 1
}

# 2. 检查并解析待编辑原图至 ComfyUI input 目录
$comfyInputFolder = Join-Path $ComfyRootDir "ComfyUI\input"
if (-not (Test-Path $comfyInputFolder)) {
    New-Item -ItemType Directory -Force -Path $comfyInputFolder | Out-Null
}

function Resolve-EditSource($p, $ws, $comfyRoot) {
    if (-not $p -or $p.Trim() -eq "") { return $null }
    if (Test-Path $p) { return (Resolve-Path $p).Path }
    $cands = @(
        (Join-Path $comfyRoot "ComfyUI\input\$p"),
        (Join-Path $comfyRoot "ComfyUI\output\$p"),
        (Join-Path $ws "生成的图片\全年龄\$p"),
        (Join-Path $ws "生成的图片\NSFW\$p"),
        (Join-Path $ws "生成的图片\$p"),
        (Join-Path $ws "成品图\全年龄\$p"),
        (Join-Path $ws "成品图\NSFW\$p"),
        (Join-Path $ws "参考图\全年龄\$p"),
        (Join-Path $ws "参考图\NSFW\$p"),
        (Join-Path $ws "参考图\$p")
    )
    foreach ($c in $cands) {
        if (Test-Path $c) { return (Resolve-Path $c).Path }
    }
    return $null
}

$resolvedImg1 = Resolve-EditSource $Image $WorkspaceDir $ComfyRootDir
if (-not $resolvedImg1) {
    Write-Error "[ImageEdit] Image not found at path or candidate directories: $Image"
    exit 1
}

$imgLeaf = Split-Path -Leaf $resolvedImg1
$destInputPath = Join-Path $comfyInputFolder $imgLeaf
if ($resolvedImg1 -ne (Resolve-Path $destInputPath -ErrorAction SilentlyContinue).Path) {
    Copy-Item -Path $resolvedImg1 -Destination $destInputPath -Force
}
Write-Host "[ImageEdit] Target Edit Image (image_1): $imgLeaf"

$secondImgLeaf = ""
$resolvedImg2 = Resolve-EditSource $SecondImage $WorkspaceDir $ComfyRootDir
if ($resolvedImg2) {
    $secondImgLeaf = Split-Path -Leaf $resolvedImg2
    $destInputPath2 = Join-Path $comfyInputFolder $secondImgLeaf
    if ($resolvedImg2 -ne (Resolve-Path $destInputPath2 -ErrorAction SilentlyContinue).Path) {
        Copy-Item -Path $resolvedImg2 -Destination $destInputPath2 -Force
    }
    Write-Host "[ImageEdit] Second Reference Image (image_2): $secondImgLeaf"
}

if ($Seed -le 0) {
    $Seed = Get-Random -Minimum 10000000000000 -Maximum 99999999999999
}

# 3. 构造通用高保真图像编辑 Prompt 字典（绝不挂载加速 LoRA，Latent 直承原图）
$nsfwPattern = "(?i)(nsfw|nude|naked|topless|bottomless|pussy|slit|vulva|genitals|anus|nipple|breast|cleavage|bareback|braless|lingerie|bikini|thong|microbikini|sheer|mesh|lace|crotch|boudoir|gravure|spreadlegs|backhips|sexy|venus|sensual|bath|69|pronelie|shower|penetration|vaginal|pelvic|busty|uncensored|sultry|macro-slit|realanatomy|裸|全裸|半裸|去衣|脱衣|私密|一线天|阴部|阴唇|乳头|巨乳|乳晕|下体|情趣|透视|内衣|比基尼|丁字裤)"
$detectedNsfw = $NSFW -or ($Prompt -match $nsfwPattern) -or ($resolvedImg1 -match "NSFW")

$activeLora = ""
$targetLoraName = "qwen2_1-femaledVaginus-nsfw-v1_3-fine_L22-31.safetensors"
$demosaicPattern = "(?i)(demosaic|mosaic|uncensor|去码|消除马赛克|去马赛克|修复马赛克|无码)"
if ($Prompt -match $demosaicPattern -or $Lora -like "*Edit*") {
    $targetLoraName = "Qwen-Image-2.1-NSFW-Image-Edit.safetensors"
}

if ($Lora.ToLower() -eq "auto") {
    if ($detectedNsfw) {
        $activeLora = $targetLoraName
    }
} elseif ($Lora -and $Lora.Trim() -ne "" -and $Lora.ToLower() -ne "none") {
    $activeLora = $Lora
}

$promptDict = @{
    "1" = @{
        class_type = "UNETLoader"
        inputs = @{
            unet_name = $Unet
            weight_dtype = "default"
        }
    }
    "2" = @{
        class_type = "CLIPLoader"
        inputs = @{
            clip_name = $Clip
            type = "qwen_image"
            device = "default"
        }
    }
    "3" = @{
        class_type = "VAELoader"
        inputs = @{
            vae_name = $Vae
        }
    }
    "9" = @{
        class_type = "LoadImage"
        inputs = @{
            image = $imgLeaf
        }
    }
    "4" = @{
        class_type = "TextEncodeQwenImage21"
        inputs = @{
            clip = @("2", 0)
            vae = @("3", 0)
            "images.image_1" = @("9", 0)
            prompt = $Prompt
            negative_prompt = $NegativePrompt
            resolution = $Resolution
        }
    }
    "6" = @{
        class_type = "KSampler"
        inputs = @{
            model = @("1", 0)             # 直连纯净 UNet，绝不经过加速 LoRA
            positive = @("4", 0)          # 来自 TextEncodeQwenImage21 的 positive
            negative = @("4", 1)          # 来自 TextEncodeQwenImage21 的 negative
            latent_image = @("4", 2)      # 来自 TextEncodeQwenImage21 输出的原图 Latent 特征锚定
            seed = $Seed
            steps = $Steps
            cfg = $Cfg
            sampler_name = $SamplerName
            scheduler = $Scheduler
            denoise = 1.0
        }
    }
    "7" = @{
        class_type = "VAEDecode"
        inputs = @{
            vae = @("3", 0)
            samples = @("6", 0)
        }
    }
    "8" = @{
        class_type = "SaveImage"
        inputs = @{
            filename_prefix = $Prefix
            images = @("7", 0)
        }
    }
}

if ($activeLora) {
    Write-Host "[ImageEdit] Injected Anatomy LoRA: $activeLora (Strength: $LoraStrength)" -ForegroundColor Magenta
    $promptDict["10"] = @{
        class_type = "LoraLoaderModelOnly"
        inputs = @{
            model = @("1", 0)
            lora_name = $activeLora
            strength_model = $LoraStrength
        }
    }
    $promptDict["6"].inputs["model"] = @("10", 0)
}

# 若提供了第二参考图（如换装参考、画风参考），挂载到 images.image_2
if ($secondImgLeaf) {
    $promptDict["11"] = @{
        class_type = "LoadImage"
        inputs = @{
            image = $secondImgLeaf
        }
    }
    $promptDict["4"].inputs["images.image_2"] = @("11", 0)
}

$payload = @{
    prompt = $promptDict
} | ConvertTo-Json -Depth 10

Write-Host "[ImageEdit] Submitting Universal Edit Task (Steps: $Steps, CFG: $Cfg, Sampler: $SamplerName/$Scheduler, Resolution: $Resolution, Seed: $Seed)..."
$resp = Invoke-RestMethod -Uri "$ComfyHost/prompt" -Method Post -Body $payload -ContentType "application/json; charset=utf-8"
$promptId = $resp.prompt_id
Write-Host "[ImageEdit] Task queued successfully. Prompt ID: $promptId"

# 4. 轮询执行进度
$timeout = 300
$elapsed = 0
$completedFile = ""

while ($elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2
    try {
        $hist = Invoke-RestMethod -Uri "$ComfyHost/history/$promptId" -Method Get
        if ($hist.$promptId.outputs.'8'.images) {
            $completedFile = $hist.$promptId.outputs.'8'.images[0].filename
            Write-Host "[ImageEdit] Generation completed in $elapsed seconds! Filename: $completedFile"
            break
        }
        if ($hist.$promptId.status.status_str -eq "error") {
            Write-Error "[ImageEdit] ComfyUI execution returned error."
            exit 1
        }
    } catch {
        # continue polling
    }
}

if (-not $completedFile) {
    Write-Error "[ImageEdit] Timeout waiting for task completion ($timeout s)."
    exit 1
}

# 5. 自动归档至工作区（区分 全年龄 / NSFW）
$sourcePath = Join-Path "$ComfyRootDir\ComfyUI\output" $completedFile
$nsfwPattern = "(?i)(nsfw|nude|naked|topless|bottomless|pussy|slit|vulva|genitals|anus|nipple|breast|cleavage|bareback|braless|lingerie|bikini|thong|microbikini|sheer|mesh|lace|crotch|boudoir|gravure|spreadlegs|backhips|sexy|venus|sensual|bath|69|pronelie|shower|penetration|vaginal|pelvic|busty|uncensored|sultry|macro-slit|realanatomy|裸|全裸|半裸|去衣|脱衣|私密|一线天|阴部|阴唇|乳头|巨乳|乳晕|下体|情趣|透视|内衣|比基尼|丁字裤)"
$isNsfw = $NSFW -or ($Prompt -match $nsfwPattern) -or ($resolvedImg1 -match "NSFW")
$category = if ($isNsfw) { "NSFW" } else { "全年龄" }
$archiveDir = Join-Path (Join-Path $WorkspaceDir $outputFolderName) $category
if (!(Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
}
$destPath = Join-Path $archiveDir $completedFile
Copy-Item -Path $sourcePath -Destination $destPath -Force
Write-Host "[ImageEdit] Final output archived to [$category]: $destPath"

[PSCustomObject]@{
    PromptId = $promptId
    Filename = $completedFile
    Category = $category
    Seed = $Seed
    Steps = $Steps
    Cfg = $Cfg
    SourcePath = $sourcePath
    WorkspacePath = $destPath
    ElapsedSeconds = $elapsed
} | ConvertTo-Json -Depth 2
