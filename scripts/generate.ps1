param (
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [Parameter(Mandatory = $false)]
    [string]$RefImage = "",

    [Parameter(Mandatory = $false)]
    [string]$RefImage2 = "",

    [Parameter(Mandatory = $false)]
    [string]$Prefix = "Viggle8-Qwen-Gen",

    [Parameter(Mandatory = $false)]
    [string]$AspectRatio = "auto",

    [Parameter(Mandatory = $false)]
    [int]$Width = 0,

    [Parameter(Mandatory = $false)]
    [int]$Height = 0,

    [Parameter(Mandatory = $false)]
    [string]$NegativePrompt = "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation",

    [Parameter(Mandatory = $false)]
    [int]$Resolution = 0,

    [Parameter(Mandatory = $false)]
    [int]$MaxRefDimension = 768,

    [Parameter(Mandatory = $false)]
    [long]$Seed = 0,

    [Parameter(Mandatory = $false)]
    [string]$ComfyHost = "http://127.0.0.1:8188",

    [Parameter(Mandatory = $false)]
    [string]$ComfyRootDir = "F:\comfyui\ComfyUI",

    [Parameter(Mandatory = $false)]
    [string]$Unet = "NoctQ_V4_int8_convrot.safetensors",

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
        "landscape" { $Width = 1152; $Height = 896 }
        "1:1" { $Width = 1024; $Height = 1024 }
        "square" { $Width = 1024; $Height = 1024 }
        "9:16" { $Width = 768; $Height = 1344 }
        "tall" { $Width = 768; $Height = 1344 }
        "2:3" { $Width = 832; $Height = 1216 }
        "3:4" { $Width = 896; $Height = 1152 }
        default { $Width = 896; $Height = 1152 }
    }
}
Write-Host "[ComfyUI] Resolved output resolution: ${Width}x${Height} ($AspectRatio)"

# 2. Check ComfyUI server and auto-start if offline
$isOnline = $false
try {
    $stats = Invoke-RestMethod -Uri "$ComfyHost/system_stats" -Method Get -TimeoutSec 3 -ErrorAction Stop
    $isOnline = $true
    Write-Host "[ComfyUI] Server online at $ComfyHost"
} catch {
    Write-Host "[ComfyUI] Server offline. Attempting automatic launch..."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $starterScript = Join-Path $scriptDir "start_comfyui.ps1"
    if (Test-Path $starterScript) {
        $started = & $starterScript -ComfyHost $ComfyHost
        if ($started -eq $true) {
            $isOnline = $true
        }
    }
}

if (-not $isOnline) {
    Write-Error "[ComfyUI] Unable to start or connect to ComfyUI at $ComfyHost."
    exit 1
}

# 3. Random seed if not provided
if ($Seed -le 0) {
    $Seed = Get-Random -Minimum 10000000000000 -Maximum 99999999999999
}

# 4. Handle Reference Image: Auto-Rescaling & Disk Space Optimization
$hasRef = $false
$refFileName = ""

function Save-OptimizedImage($srcPath, $dstPath, $maxDim) {
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($srcPath)
    $origW = $img.Width
    $origH = $img.Height

    if ($origW -gt $maxDim -or $origH -gt $maxDim) {
        $scale = [Math]::Min([double]$maxDim / $origW, [double]$maxDim / $origH)
        $newW = [int][Math]::Round($origW * $scale)
        $newH = [int][Math]::Round($origH * $scale)

        $destBmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $g = [System.Drawing.Graphics]::FromImage($destBmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.DrawImage($img, 0, 0, $newW, $newH)
        $img.Dispose()
        $g.Dispose()

        $tempOut = $dstPath + ".tmp"
        $destBmp.Save($tempOut, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $destBmp.Dispose()
        Move-Item -Path $tempOut -Destination $dstPath -Force
        Write-Host "[ComfyUI] Optimized reference image from ${origW}x${origH} to ${newW}x${newH}."
    } else {
        $img.Dispose()
        if ($srcPath -ne $dstPath) {
            Copy-Item -Path $srcPath -Destination $dstPath -Force
        }
    }
}

function Process-RefImageFile($imgPath, $maxDim, $comfyRoot, $wsDir, $refFldr) {
    if (-not $imgPath -or $imgPath.Trim() -eq "") { return $null }
    $destInputFolder = Join-Path $comfyRoot "ComfyUI\input"
    if (!(Test-Path $destInputFolder)) {
        New-Item -ItemType Directory -Force -Path $destInputFolder | Out-Null
    }

    if (Test-Path $imgPath) {
        $refName = Split-Path -Leaf $imgPath
        $destInput = Join-Path $destInputFolder $refName
        $refArchiveDir = Join-Path $wsDir $refFldr
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
            clip_name = "qwen3vl_8b_nvfp4.safetensors"
            type = "qwen_image"
            device = "default"
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
    Write-Host "[ComfyUI] Using T8 Acceleration Sampler (4-Step Fun-Acc PDD)"
    $promptDict["6"] = @{
        class_type = "T8QwenImage21FunAccPDD4Step"
        inputs = @{
            model = $modelSource
            positive = @("4", 0)
            latent_image = @("5", 0)
            model_file = "Qwen-Image-2.1-Fun-Acc-4Step-PDD-T8.safetensors"
            seed = $Seed
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
            Write-Error "[ComfyUI] Execution returned error in history status."
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

# 9. Output summary JSON
$result = [PSCustomObject]@{
    PromptId = $promptId
    Filename = $completedFile
    Seed = $Seed
    Width = $Width
    Height = $Height
    AspectRatio = $AspectRatio
    SourcePath = $sourcePath
    WorkspacePath = $destPath
    ElapsedSeconds = $elapsed
}

return ($result | ConvertTo-Json)
