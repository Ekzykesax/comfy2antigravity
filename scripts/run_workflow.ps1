param (
    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath = "",

    [Parameter(Mandatory = $false)]
    [string]$Prompt = "",

    [Parameter(Mandatory = $false)]
    [string]$RefImage = "",

    [Parameter(Mandatory = $false)]
    [long]$Seed = 0,

    [Parameter(Mandatory = $false)]
    [string]$ComfyHost = "http://127.0.0.1:8188",

    [Parameter(Mandatory = $false)]
    [string]$ComfyRootDir = "",

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceDir = ""
)

$ErrorActionPreference = "Stop"

# Auto-detect ComfyRootDir if not set
if (-not $ComfyRootDir -or (-not (Test-Path $ComfyRootDir))) {
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

# Auto-detect WorkspaceDir
$defaultWorkspaceFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("Q29tZnlVSeeUn+WbvuaIkOaenA==")) # "ComfyUI生图成果"
$outputFolderName = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("55Sf5oiQ55qE5Zu+54mH")) # "生成的图片"

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

# Ensure ComfyUI is running
$isOnline = $false
try {
    $stats = Invoke-RestMethod -Uri "$ComfyHost/system_stats" -Method Get -TimeoutSec 3 -ErrorAction Stop
    $isOnline = $true
} catch {
    Write-Host "[ComfyUI] Server offline. Attempting automatic launch..."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $starterScript = Join-Path $scriptDir "start_comfyui.ps1"
    if (Test-Path $starterScript) {
        $started = & $starterScript -ComfyHost $ComfyHost
        if ($started -eq $true) { $isOnline = $true }
    }
}

if (-not $isOnline) {
    Write-Error "[ComfyUI] Unable to start or connect to ComfyUI at $ComfyHost."
    exit 1
}

# If no custom workflow is provided, fall back to default flagship generate.ps1
if (-not $WorkflowPath -or $WorkflowPath.Trim() -eq "" -or (-not (Test-Path $WorkflowPath))) {
    Write-Host "[ComfyUI] No custom workflow JSON provided. Using built-in flagship Qwen-Image pipeline..."
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $flagshipScript = Join-Path $scriptDir "generate.ps1"
    & $flagshipScript -Prompt $Prompt -RefImage $RefImage -Seed $Seed -ComfyHost $ComfyHost -WorkspaceDir $WorkspaceDir
    exit 0
}

# Load custom workflow JSON (API format)
Write-Host "[ComfyUI] Loading custom workflow: $WorkflowPath"
$rawJson = Get-Content -Path $WorkflowPath -Raw -Encoding UTF8
$workflow = $rawJson | ConvertFrom-Json

# Generate seed if not provided
if ($Seed -le 0) {
    $Seed = Get-Random -Minimum 10000000000000 -Maximum 99999999999999
}

# Inject seed and prompt into custom workflow where applicable
foreach ($nodeId in $workflow.PSObject.Properties.Name) {
    $node = $workflow.$nodeId
    if ($node.inputs) {
        # Update seed
        if ($node.inputs.seed -ne $null) {
            $node.inputs.seed = $Seed
        }
        # Update text prompt if provided and node looks like positive text encoder
        if ($Prompt -and $node.inputs.text -ne $null) {
            if ($node._meta.title -match "Positive|正向" -or ($node.class_type -match "CLIPTextEncode" -and -not ($node.inputs.text -match "ugly|bad|deformed"))) {
                $node.inputs.text = $Prompt
            }
        }
    }
}

# Submit custom workflow to ComfyUI
$payload = @{
    prompt = $workflow
    client_id = "antigravity-custom-agent"
}
$postBody = $payload | ConvertTo-Json -Depth 20

Write-Host "[ComfyUI] Submitting custom workflow prompt..."
$res = Invoke-RestMethod -Uri "$ComfyHost/prompt" -Method Post -Body $postBody -ContentType "application/json; charset=utf-8"
$promptId = $res.prompt_id
Write-Host "[ComfyUI] Task submitted successfully. Prompt ID: $promptId"

# Poll execution until done
$startTime = Get-Date
while ($true) {
    Start-Sleep -Seconds 2
    try {
        $hist = Invoke-RestMethod -Uri "$ComfyHost/history/$promptId" -Method Get -TimeoutSec 5 -ErrorAction Stop
        if ($hist.$promptId) {
            $outputs = $hist.$promptId.outputs
            $foundFile = $null
            foreach ($k in $outputs.PSObject.Properties.Name) {
                if ($outputs.$k.images -and $outputs.$k.images.Count -gt 0) {
                    $foundFile = $outputs.$k.images[0].filename
                    break
                }
            }
            if ($foundFile) {
                $elapsed = [Math]::Round(((Get-Date) - $startTime).TotalSeconds)
                Write-Host "[ComfyUI] Completed in $elapsed seconds. Filename: $foundFile"
                
                # Copy to workspace
                $destDir = Join-Path $WorkspaceDir $outputFolderName
                if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Force -Path $destDir | Out-Null }
                
                $candidates = @(
                    Join-Path $ComfyRootDir "ComfyUI\output\$foundFile",
                    Join-Path $ComfyRootDir "output\$foundFile"
                )
                $src = $null
                foreach ($c in $candidates) {
                    if (Test-Path $c) { $src = $c; break }
                }
                
                if ($src) {
                    $finalDest = Join-Path $destDir $foundFile
                    Copy-Item -Path $src -Destination $finalDest -Force
                    Write-Host "[ComfyUI] Saved to workspace: $finalDest"
                }
                break
            }
        }
    } catch {
        # continue polling
    }
}
