param(
    [Parameter(Mandatory = $false)]
    [string]$ComfyHost = "http://127.0.0.1:8188",

    [Parameter(Mandatory = $false)]
    [string]$ComfyRootDir = "F:\comfyui\ComfyUI",

    [Parameter(Mandatory = $false)]
    [switch]$LaunchDesktopApp,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"

# 1. Check if ComfyUI is already running
try {
    $stats = Invoke-RestMethod -Uri "$ComfyHost/system_stats" -Method Get -TimeoutSec 3 -ErrorAction Stop
    Write-Host "[ComfyUI] Server is ALREADY running at $ComfyHost"
    return $true
} catch {
    Write-Host "[ComfyUI] Server offline. Initializing auto-launch..."
}

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

# 2. Locate executables
$desktopExe = Join-Path $env:LOCALAPPDATA "Programs\Comfy Desktop\Comfy Desktop.exe"
$pythonExe = Join-Path $ComfyRootDir "ComfyUI\.venv\Scripts\python.exe"
$mainPy = Join-Path $ComfyRootDir "ComfyUI\main.py"

if ($LaunchDesktopApp -and (Test-Path $desktopExe)) {
    Write-Host "[ComfyUI] Launching via Comfy Desktop App: $desktopExe"
    Start-Process -FilePath $desktopExe
} elseif ((Test-Path $pythonExe) -and (Test-Path $mainPy)) {
    Write-Host "[ComfyUI] Launching headless backend via Python venv: $pythonExe"
    $inputDir = Join-Path $ComfyRootDir "ComfyUI\input"
    $outputDir = Join-Path $ComfyRootDir "ComfyUI\output"
    $argList = @(
        "-s",
        "ComfyUI\main.py",
        "--feature-flag", "show_signin_button=true",
        "--feature-flag", "enable_telemetry=true",
        "--enable-assets",
        "--enable-manager",
        "--input-directory", "$inputDir",
        "--output-directory", "$outputDir"
    )
    Start-Process -FilePath $pythonExe -ArgumentList $argList -WorkingDirectory $ComfyRootDir -WindowStyle Hidden
} elseif (Test-Path $desktopExe) {
    Write-Host "[ComfyUI] Falling back to Comfy Desktop: $desktopExe"
    Start-Process -FilePath $desktopExe
} else {
    Write-Error "[ComfyUI] Could not find ComfyUI backend ($pythonExe) or Desktop App ($desktopExe)."
    return $false
}

# 3. Wait for port to become active
Write-Host "[ComfyUI] Waiting for server to initialize..."
$waited = 0
while ($waited -lt $TimeoutSeconds) {
    Start-Sleep -Seconds 3
    $waited += 3
    try {
        $stats = Invoke-RestMethod -Uri "$ComfyHost/system_stats" -Method Get -TimeoutSec 2 -ErrorAction Stop
        if ($stats) {
            Write-Host "[ComfyUI] Server is UP and READY at $ComfyHost (took ${waited}s)!"
            return $true
        }
    } catch {
        Write-Host "[ComfyUI] Waiting for startup (${waited}/${TimeoutSeconds}s)..."
    }
}

Write-Error "[ComfyUI] Startup timed out after ${TimeoutSeconds}s."
return $false
