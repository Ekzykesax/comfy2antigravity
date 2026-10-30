<#
.SYNOPSIS
    blend_anime_real.ps1 - 二次元角色实景融合专属调度脚本 (渡月桥殿堂级黄金范式)
.DESCRIPTION
    将二次元角色（图1）与真实世界摄影背景（图2）无缝融合：
    - 纯正 2D 动漫面容（武内崇/新海诚式灵动大眼），杜绝 3D 塑料感与低质黑线描边
    - 侧逆轮廓光 (Rim Light) 与深邃环境闭塞阴影 (AO) 雕刻油画级体积感
    - 单反大光圈光学浅景深散景虚化 (Creamy Optical Bokeh)
    - 纯净原生 25 步，杜绝 Turbo 污染
.EXAMPLE
    .\blend_anime_real.ps1 -CharRef "saber_casual_ref.png" -BgRef "ref_lawson_fuji_bg.png" -Resolution "3M"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$CharRef,

    [Parameter(Mandatory=$true)]
    [string]$BgRef,

    [Parameter(Mandatory=$false)]
    [string]$CharDesc = "",

    [Parameter(Mandatory=$false)]
    [string]$BgDesc = "",

    [Parameter(Mandatory=$false)]
    [string]$PoseDesc = "16:9经典宽画幅电影构图，半身肖像近景特写(upper body medium close-up bust shot)，人物自然位于画面一侧近景，身体微倾自然面向镜头，神态温柔端庄，嘴角带着浅浅柔和的微笑",

    [Parameter(Mandatory=$false)]
    [string]$Resolution = "3M",

    [Parameter(Mandatory=$false)]
    [int]$Steps = 25,

    [Parameter(Mandatory=$false)]
    [float]$Cfg = 3.5,

    [Parameter(Mandatory=$false)]
    [int]$Seed = 0,

    [Parameter(Mandatory=$false)]
    [string]$Prefix = "Anime-RealWorld-Blend",

    [Parameter(Mandatory=$false)]
    [string]$ComfyHost = "http://127.0.0.1:8188",

    [Parameter(Mandatory=$false)]
    [switch]$Nsfw
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pyScript = Join-Path $scriptDir "blend_anime_real.py"
if (-not (Test-Path $pyScript)) {
    $pyScript = Join-Path $scriptDir ".agents\skills\comfy2antigravity\scripts\blend_anime_real.py"
}

# Find Python executable
$pythonExe = "python"
$venvCandidates = @(
    "F:\comfyui\ComfyUI\ComfyUI\.venv\Scripts\python.exe",
    "F:\comfyui\ComfyUI\.venv\Scripts\python.exe",
    "C:\ComfyUI_windows_portable\python_embeded\python.exe"
)
foreach ($c in $venvCandidates) {
    if (Test-Path $c) {
        $pythonExe = $c
        break
    }
}

$cmdArgs = @(
    "`"$pyScript`"",
    "--char-ref", "`"$CharRef`"",
    "--bg-ref", "`"$BgRef`"",
    "--resolution", "`"$Resolution`"",
    "--steps", "$Steps",
    "--cfg", "$Cfg",
    "--seed", "$Seed",
    "--prefix", "`"$Prefix`"",
    "--comfy-host", "`"$ComfyHost`""
)

if ($CharDesc) {
    $cmdArgs += @("--char-desc", "`"$CharDesc`"")
}
if ($BgDesc) {
    $cmdArgs += @("--bg-desc", "`"$BgDesc`"")
}
if ($PoseDesc) {
    $cmdArgs += @("--pose-desc", "`"$PoseDesc`"")
}
if ($Nsfw) {
    $cmdArgs += @("--nsfw")
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  🎨 二次元实景融合专属管线 (渡月桥殿堂级黄金范式)" -ForegroundColor Yellow
Write-Host "  人物立绘: $CharRef" -ForegroundColor Green
Write-Host "  实景背景: $BgRef" -ForegroundColor Green
Write-Host "  分辨率:   $Resolution (原生 $Steps 步, CFG $Cfg)" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

& $pythonExe $cmdArgs
