param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Image,

    [Parameter(Mandatory = $false)]
    [string]$Alias = ""
)

$ErrorActionPreference = "Stop"

$finishedDir = "C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\成品图"
$generatedDir = "C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\生成的图片"
$comfyOut = "F:\comfyui\ComfyUI\ComfyUI\output"

if (-not (Test-Path $finishedDir)) {
    New-Item -ItemType Directory -Path $finishedDir -Force | Out-Null
}

$srcPath = $Image
if (-not (Test-Path $srcPath)) {
    $cand1 = Join-Path $generatedDir $Image
    $cand2 = Join-Path $comfyOut $Image
    if (Test-Path $cand1) {
        $srcPath = $cand1
    } elseif (Test-Path $cand2) {
        $srcPath = $cand2
    } else {
        Write-Error "找不到指定图片: $Image"
        exit 1
    }
}

$filename = Split-Path -Leaf $srcPath
if ($Alias -ne "") {
    $ext = [System.IO.Path]::GetExtension($filename)
    if (-not $Alias.EndsWith($ext)) {
        $filename = "$Alias$ext"
    } else {
        $filename = $Alias
    }
}

$destPath = Join-Path $finishedDir $filename
Copy-Item -Path $srcPath -Destination $destPath -Force
Write-Host "[成品图] 满意作品已成功归档至: $destPath"
