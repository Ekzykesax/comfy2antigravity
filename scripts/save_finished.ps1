param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Image,

    [Parameter(Mandatory = $false)]
    [string]$Alias = "",

    [Parameter(Mandatory = $false)]
    [switch]$NSFW
)

$ErrorActionPreference = "Stop"

$finishedDir = "C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\成品图"
$generatedDir = "C:\Users\84021\Desktop\Antigravity\ComfyUI生图成果\生成的图片"
$comfyOut = "F:\comfyui\ComfyUI\ComfyUI\output"

$srcPath = $Image
if (-not (Test-Path $srcPath)) {
    $cands = @(
        (Join-Path $generatedDir (Join-Path "全年龄" $Image)),
        (Join-Path $generatedDir (Join-Path "NSFW" $Image)),
        (Join-Path $generatedDir $Image),
        (Join-Path $finishedDir (Join-Path "全年龄" $Image)),
        (Join-Path $finishedDir (Join-Path "NSFW" $Image)),
        (Join-Path $comfyOut $Image)
    )
    foreach ($c in $cands) {
        if (Test-Path $c) {
            $srcPath = $c
            break
        }
    }
    if (-not (Test-Path $srcPath)) {
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

$nsfwPattern = "(?i)(nsfw|nude|naked|topless|bottomless|pussy|slit|vulva|genitals|anus|nipple|breast|cleavage|bareback|braless|lingerie|bikini|thong|microbikini|sheer|mesh|lace|crotch|boudoir|gravure|spreadlegs|backhips|sexy|venus|sensual|bath|69|pronelie|shower|penetration|vaginal|pelvic|busty|uncensored|sultry|macro-slit|realanatomy|裸|全裸|半裸|去衣|脱衣|私密|一线天|阴部|阴唇|乳头|巨乳|乳晕|下体|情趣|透视|内衣|比基尼|丁字裤)"
$isNsfw = $NSFW -or ($srcPath -match "NSFW") -or ($filename -match $nsfwPattern)
$category = if ($isNsfw) { "NSFW" } else { "全年龄" }

$targetCategoryDir = Join-Path $finishedDir $category
if (-not (Test-Path $targetCategoryDir)) {
    New-Item -ItemType Directory -Path $targetCategoryDir -Force | Out-Null
}

$destPath = Join-Path $targetCategoryDir $filename
Copy-Item -Path $srcPath -Destination $destPath -Force
Write-Host "[成品图] 满意作品已成功归档至 [$category]: $destPath"
