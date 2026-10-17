param (
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [Parameter(Mandatory = $false)]
    [string]$RefImage = "",

    [Parameter(Mandatory = $false)]
    [string]$RefImage2 = "",

    [Parameter(Mandatory = $false)]
    [string]$Prefix = "GGUF-Q4K-NoctQ",

    [Parameter(Mandatory = $false)]
    [string]$AspectRatio = "auto",

    [Parameter(Mandatory = $false)]
    [int]$Width = 0,

    [Parameter(Mandatory = $false)]
    [int]$Height = 0,

    [Parameter(Mandatory = $false)]
    [string]$NegativePrompt = "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation",

    [Parameter(Mandatory = $false)]
    [int]$Resolution = 1024,

    [Parameter(Mandatory = $false)]
    [int]$MaxRefDimension = 1024,

    [Parameter(Mandatory = $false)]
    [long]$Seed = 0,

    [Parameter(Mandatory = $false)]
    [string]$ComfyHost = "http://127.0.0.1:8188",

    [Parameter(Mandatory = $false)]
    [string]$ComfyRootDir = "F:\comfyui\ComfyUI",

    [Parameter(Mandatory = $false)]
    [string]$Unet = "NoctQ_V4_int8_convrot.safetensors",

    [Parameter(Mandatory = $false)]
    [string]$GgufClip = "Qwen-Image-2.1-Turbo-Uncensored-AD-Q4_K.gguf",

    [Parameter(Mandatory = $false)]
    [string]$VisionSource = "mmproj-Qwen-Image-2.1-Turbo-Uncensored-F16.gguf",

    [Parameter(Mandatory = $false)]
    [string]$Lora = "none",

    [Parameter(Mandatory = $false)]
    [double]$LoraStrength = 1.0,

    [Parameter(Mandatory = $false)]
    [string]$Sampler = "viggle",

    [Parameter(Mandatory = $false)]
    [int]$Steps = 8,

    [Parameter(Mandatory = $false)]
    [double]$Cfg = 1.0,

    [Parameter(Mandatory = $false)]
    [string]$SamplerName = "euler",

    [Parameter(Mandatory = $false)]
    [string]$Scheduler = "simple",

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceDir = ""
)

$ErrorActionPreference = "Stop"

# Auto-detect ComfyRootDir if default does not exist
if (-not (Test-Path $ComfyRootDir)) {
    if ($env:COMFYUI_ROOT -and (Test-Path $env:COMFYUI_ROOT)) {
        $ComfyRootDir = $env:COMFYUI_ROOT
    } else {
        $candidates = @(
            "F:\comfyui\ComfyUI",
            "C:\ComfyUI_windows_portable",
            "D:\ComfyUI_windows_portable",
            "E:\ComfyUI_windows_portable",
            "C:\ComfyUI",
            "D:\ComfyUI"
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) {
                $ComfyRootDir = $c
                break
            }
        }
    }
}

# Pure ASCII folder name resolution to prevent Windows PowerShell encoding mismatch
$defaultWorkspaceFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("Q29tZnlVSeeUn+WbvuaIkOaenA==")) # "ComfyUI生图成果"
$outputFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("55Sf5oiQ55qE5Zu+54mH")) # "生成的图片"
$refFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("5Y+C6ICD5Zu+")) # "参考图"

if (-not $WorkspaceDir -or $WorkspaceDir.Trim() -eq "") {
    if ($env:COMFY_WORKSPACE_DIR -and (Test-Path $env:COMFY_WORKSPACE_DIR)) {
        $WorkspaceDir = $env:COMFY_WORKSPACE_DIR
    } else {
        $baseDir = $PWD.Path
        if (-not (Test-Path $baseDir)) {
            $baseDir = Join-Path $env:USERPROFILE "Desktop"
        }
        $WorkspaceDir = Join-Path $baseDir $defaultWorkspaceFolderName
    }
}

# 1. Resolve Adaptive Resolution based on scene and AspectRatio
if ($Width -le 0 -or $Height -le 0) {
    $ar = $AspectRatio.ToLower().Trim()
    if ($ar -eq "auto") {
        # Intelligent detection from prompt semantics
        if ($Prompt -match "横构图|横屏|宽幅|电影|风景|双人|全景|cinematic|landscape") {
            $ar = "16:9"
        } elseif ($Prompt -match "躺在|趴在|俯卧|卧姿|床榻|沙发") {
            $ar = "4:3"
        } elseif ($Prompt -match "头像|特写|大头照|正方形|square|icon") {
            $ar = "1:1"
        } elseif ($Prompt -match "全身|立绘|挺拔|长腿|手机壁纸|tall|full-body") {
            $ar = "9:16"
        } else {
            $ar = "3:4" # Default classic portrait
        }
    }

    switch ($ar) {
        "16:9" { $Width = 1344; $Height = 768 }
        "cinematic" { $Width = 1344; $Height = 768 }
        "4:3" { $Width = 1152; $Height = 896 }
        "1:1" { $Width = 1024; $Height = 1024 }
        "square" { $Width = 1024; $Height = 1024 }
        "3:4" { $Width = 896; $Height = 1152 }
        "portrait" { $Width = 896; $Height = 1152 }
        "9:16" { $Width = 768; $Height = 1344 }
        "wallpaper" { $Width = 768; $Height = 1344 }
        default { $Width = 896; $Height = 1152 }
    }
}
Write-Host "[ComfyUI] Resolved output resolution: ${Width}x${Height} ($AspectRatio)"

# 2. Check & Auto-launch ComfyUI Server if offline
try {
    $stats = Invoke-RestMethod -Uri "$ComfyHost/system_stats" -Method Get -TimeoutSec 3 -ErrorAction Stop
    Write-Host "[ComfyUI] Server online at $ComfyHost"
} catch {
    Write-Host "[ComfyUI] Server offline. Attempting automatic launch..."
    $startScript = Join-Path $PSScriptRoot "start_comfyui.ps1"
    if (Test-Path $startScript) {
        & $startScript -ComfyHost $ComfyHost -ComfyRootDir $ComfyRootDir -TimeoutSeconds 60
    } else {
        Write-Error "[ComfyUI] Server is not running at $ComfyHost and start script not found at $startScript."
        exit 1
    }
}

# 3. Handle Random Seed
if ($Seed -le 0) {
    $Seed = Get-Random -Minimum 10000000000000 -Maximum 99999999999999
}

# 4. Helper Function: Resize and Preprocess Reference Images
function Save-OptimizedImage {
    param (
        [string]$SourcePath,
        [string]$TargetPath,
        [int]$MaxDim = 1024
    )

    try {
        Add-Type -AssemblyName System.Drawing
        $img = [System.Drawing.Image]::FromFile($SourcePath)
        $w = $img.Width
        $h = $img.Height

        if ($w -gt $MaxDim -or $h -gt $MaxDim) {
            if ($w -gt $h) {
                $newW = $MaxDim
                $newH = [int]($h * ($MaxDim / $w))
            } else {
                $newH = $MaxDim
                $newW = [int]($w * ($MaxDim / $h))
            }
            $bmp = New-Object System.Drawing.Bitmap $newW, $newH
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.DrawImage($img, 0, 0, $newW, $newH)
            $g.Dispose()
            $img.Dispose()

            $ext = [System.IO.Path]::GetExtension($TargetPath).ToLower()
            if ($ext -eq ".png") {
                $bmp.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
            } else {
                $bmp.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            }
            $bmp.Dispose()
        } else {
            $img.Dispose()
            if ($SourcePath -ne $TargetPath) {
                Copy-Item -Path $SourcePath -Destination $TargetPath -Force
            }
        }
    } catch {
        if ($SourcePath -ne $TargetPath) {
            Copy-Item -Path $SourcePath -Destination $TargetPath -Force
        }
    }
}

function Process-RefImageFile {
    param (
        [string]$imgPath,
        [int]$maxDim,
        [string]$ComfyRootDir,
        [string]$WorkspaceDir,
        [string]$refFolderName
    )

    if (-not $imgPath -or $imgPath.Trim() -eq "") {
        return ""
    }

    $destInputFolder = Join-Path "$ComfyRootDir\ComfyUI\input" ""
    if (!(Test-Path $destInputFolder)) {
        New-Item -ItemType Directory -Force -Path $destInputFolder | Out-Null
    }

    if (Test-Path $imgPath) {
        $refName = Split-Path $imgPath -Leaf
        $destInput = Join-Path $destInputFolder $refName
        $refArchiveDir = Join-Path $WorkspaceDir $refFolderName
        if (!(Test-Path $refArchiveDir)) {
            New-Item -ItemType Directory -Force -Path $refArchiveDir | Out-Null
        }
        $destRefArchive = Join-Path $refArchiveDir $refName

        Save-OptimizedImage $imgPath $destInput $maxDim
        if ($imgPath -ne $destRefArchive) {
            Copy-Item -Path $destInput -Destination $destRefArchive -Force
        }
        if (Test-Path $imgPath) {
            Save-OptimizedImage $imgPath $imgPath $maxDim
        }
        return $refName
    } else {
        $refName = $imgPath
        $destInput = Join-Path $destInputFolder $refName
        if (Test-Path $destInput) {
            Save-OptimizedImage $destInput $destInput $maxDim
        }
        return $refName
    }
}

$refFile1 = Process-RefImageFile $RefImage $MaxRefDimension $ComfyRootDir $WorkspaceDir $refFolderName
$refFile2 = Process-RefImageFile $RefImage2 $MaxRefDimension $ComfyRootDir $WorkspaceDir $refFolderName

if ($refFile1) { Write-Host "[ComfyUI] Reference image 1 (Picture 1): $refFile1" }
if ($refFile2) { Write-Host "[ComfyUI] Reference image 2 (Picture 2): $refFile2" }

# 5. Construct Prompt Nodes
$modelSource = @("1", 0)
$clipSource = @("2", 0)

$useLora = ($Lora -and $Lora.Trim() -ne "" -and $Lora.ToLower() -ne "none")
if ($useLora) {
    Write-Host "[ComfyUI] Enabling LoRA: $Lora (Strength: $LoraStrength)"
    $modelSource = @("11", 0)
    $clipSource = @("11", 1)
}

$node4Inputs = @{
    clip = $clipSource
    vae = @("3", 0)
    prompt = $Prompt
    negative_prompt = $NegativePrompt
    resolution = $Resolution
}

if ($refFile1) {
    $node4Inputs["images.image_1"] = @("9", 0)
}
if ($refFile2) {
    $node4Inputs["images.image_2"] = @("10", 0)
}

Write-Host "[ComfyUI] Using Diffusion Model: $Unet"
Write-Host "[ComfyUI] Using GGUF Language Encoder: $GgufClip"
Write-Host "[ComfyUI] Using Vision Source: $VisionSource"

$promptDict = @{
    "1" = @{
        class_type = "UNETLoader"
        inputs = @{
            unet_name = $Unet
            weight_dtype = "default"
        }
    }
    "2" = @{
        class_type = "FisherQwen21GGUFCLIP"
        inputs = @{
            clip_name = $GgufClip
            vision_source = $VisionSource
        }
    }
    "3" = @{
        class_type = "VAELoader"
        inputs = @{
            vae_name = "qwen_image_2.1_vae_bf16.safetensors"
        }
    }
    "4" = @{
        class_type = "TextEncodeQwenImage21"
        inputs = $node4Inputs
    }
    "5" = @{
        class_type = "EmptyLatentImage"
        inputs = @{
            width = $Width
            height = $Height
            batch_size = 1
        }
    }
    "7" = @{
        class_type = "VAEDecode"
        inputs = @{
            samples = @("6", 0)
            vae = @("3", 0)
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

$samplerType = $Sampler.ToLower().Trim()

if ($samplerType -eq "viggle") {
    Write-Host "[ComfyUI] Using Viggle Turbo Sampler ($Steps steps, $SamplerName, $Scheduler, cfg: $Cfg)"
    $promptDict["12"] = @{
        class_type = "LoraLoader"
        inputs = @{
            model = $modelSource
            clip = $clipSource
            lora_name = "Qwen-Image-2.1-viggle-turbo-4step-lora-r64.safetensors"
            strength_model = 1.0
            strength_clip = 1.0
        }
    }
    $finalModelSource = @("12", 0)

    $promptDict["6"] = @{
        class_type = "KSampler"
        inputs = @{
            model = $finalModelSource
            positive = @("4", 0)
            negative = @("4", 1)
            latent_image = @("5", 0)
            seed = $Seed
            steps = $Steps
            cfg = $Cfg
            sampler_name = $SamplerName
            scheduler = $Scheduler
            denoise = 1.0
        }
    }
} elseif ($samplerType -eq "native" -or $samplerType -eq "base" -or $samplerType -eq "standard") {
    if ($Cfg -eq 1.0) { $Cfg = 3.5 }
    Write-Host "[ComfyUI] Using Native Non-Accelerated Sampler ($Steps steps, $SamplerName, $Scheduler, cfg: $Cfg)"
    $promptDict["6"] = @{
        class_type = "KSampler"
        inputs = @{
            model = $modelSource
            positive = @("4", 0)
            negative = @("4", 1)
            latent_image = @("5", 0)
            seed = $Seed
            steps = $Steps
            cfg = $Cfg
            sampler_name = $SamplerName
            scheduler = $Scheduler
            denoise = 1.0
        }
    }
} else {
    Write-Host "[ComfyUI] Using T8 Acceleration Sampler ($Steps steps, $SamplerName, $Scheduler, cfg: $Cfg)"
    $promptDict["6"] = @{
        class_type = "T8QwenImage21FunAccPDD4Step"
        inputs = @{
            model = $modelSource
            positive = @("4", 0)
            negative = @("4", 1)
            latent_image = @("5", 0)
            seed = $Seed
            steps = $Steps
            cfg = $Cfg
            sampler_name = $SamplerName
            scheduler = $Scheduler
            denoise = 1.0
        }
    }
}

if ($useLora) {
    $promptDict["11"] = @{
        class_type = "LoraLoader"
        inputs = @{
            model = @("1", 0)
            clip = @("2", 0)
            lora_name = $Lora
            strength_model = $LoraStrength
            strength_clip = $LoraStrength
        }
    }
}

if ($refFile1) {
    $promptDict["9"] = @{
        class_type = "LoadImage"
        inputs = @{
            image = $refFile1
        }
    }
}
if ($refFile2) {
    $promptDict["10"] = @{
        class_type = "LoadImage"
        inputs = @{
            image = $refFile2
        }
    }
}

$payload = @{
    prompt = $promptDict
} | ConvertTo-Json -Depth 10

# 6. Submit to ComfyUI
Write-Host "[ComfyUI] Submitting prompt (${Width}x${Height}, Seed: $Seed)..."
$resp = Invoke-RestMethod -Uri "$ComfyHost/prompt" -Method Post -Body $payload -ContentType "application/json; charset=utf-8"
$promptId = $resp.prompt_id
Write-Host "[ComfyUI] Task submitted successfully. Prompt ID: $promptId"

# 7. Polling for Completion
$timeout = [Math]::Max(180, ($Steps * 15) + 120)
$elapsed = 0
$completedFile = ""

while ($elapsed -lt $timeout) {
    Start-Sleep -Seconds 2
    $elapsed += 2
    try {
        $hist = Invoke-RestMethod -Uri "$ComfyHost/history/$promptId" -Method Get
        if ($hist.$promptId.outputs.'8'.images) {
            $completedFile = $hist.$promptId.outputs.'8'.images[0].filename
            Write-Host "[ComfyUI] Completed in $elapsed seconds. Filename: $completedFile"
            break
        }
        if ($hist.$promptId.status.status_str -eq "error") {
            Write-Error "[ComfyUI] Execution returned error in history status: $($hist.$promptId.status.messages | ConvertTo-Json)"
            exit 1
        }
    } catch {
        # ignore transient connection errors during polling
    }
}

if (-not $completedFile) {
    Write-Error "[ComfyUI] Timeout waiting for task $promptId after $timeout seconds."
    exit 1
}

# 8. Copy to Workspace Archive
$sourcePath = Join-Path "$ComfyRootDir\ComfyUI\output" $completedFile
$archiveDir = Join-Path $WorkspaceDir $outputFolderName
if (!(Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
}
$destPath = Join-Path $archiveDir $completedFile
Copy-Item -Path $sourcePath -Destination $destPath -Force

Write-Host "[ComfyUI] Saved to workspace: $destPath"

[PSCustomObject]@{
    PromptId = $promptId
    Filename = $completedFile
    Seed = $Seed
    Width = $Width
    Height = $Height
    AspectRatio = $AspectRatio
    SourcePath = $sourcePath
    WorkspacePath = $destPath
    ElapsedSeconds = $elapsed
} | ConvertTo-Json -Depth 4
