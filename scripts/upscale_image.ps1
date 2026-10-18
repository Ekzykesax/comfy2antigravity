param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Image,

    [Parameter(Mandatory = $false)]
    [int]$Width = 3840,

    [Parameter(Mandatory = $false)]
    [int]$Height = 0,

    [Parameter(Mandatory = $false)]
    [string]$Model = "4x_foolhardy_Remacri.pth",

    [Parameter(Mandatory = $false)]
    [string]$Prefix = "4K-Remacri-Bokeh",

    [Parameter(Mandatory = $false)]
    [switch]$DisableBokehPreserve,

    [Parameter(Mandatory = $false)]
    [switch]$NSFW
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyScript = Join-Path $scriptDir "upscale_image.py"

# Python interpreter
$pythonExe = "F:\comfyui\ComfyUI\ComfyUI\.venv\Scripts\python.exe"
if (-not (Test-Path $pythonExe)) {
    $pythonExe = "python"
}

$cmdArgs = @(
    "`"$pyScript`"",
    "--image", "`"$Image`"",
    "--target_width", "$Width",
    "--target_height", "$Height",
    "--model", "`"$Model`"",
    "--prefix", "`"$Prefix`""
)

if ($DisableBokehPreserve) {
    $cmdArgs += "--disable_bokeh_preserve"
}
if ($NSFW) {
    $cmdArgs += "--nsfw"
}

Write-Host "[Upscale] Running Focus-Aware Bokeh-Preserved 4K Upscale: $Image -> ${Width}px..."
& $pythonExe $cmdArgs
