# ============================================================================
# build.ps1 —— 生成图标并编译 HD2-CNChat.ahk 为 EXE
# Copyright (C) 2025-2026 崔素妍 及贡献者
# 本程序是自由软件，以 GNU GPL v3（GPL-3.0-or-later）授权，详见随附 LICENSE。
# ============================================================================
# 用法：右键“使用 PowerShell 运行”，或 pwsh -File build.ps1
# 前置：已安装 AutoHotkey v2（自带 Ahk2Exe 编译器）

$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot
$iconPath = Join-Path $dir "HD2-CNChat.ico"
$scriptPath = Join-Path $dir "HD2-CNChat.ahk"
$exePath = Join-Path $dir "HD2-CNChat.exe"

# ---------- 1. 生成图标（深色底 + 金色“中”字，多尺寸 ICO） ----------
function New-AppIcon([string]$outPath) {
    Add-Type -AssemblyName System.Drawing
    $sizes = @(16, 32, 48, 256)
    $pngs = @()
    foreach ($s in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap($s, $s)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.Clear([System.Drawing.Color]::FromArgb(255, 21, 23, 26))
        $font = New-Object System.Drawing.Font("Microsoft YaHei UI", ($s * 0.66), [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 204, 0))
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $rect = New-Object System.Drawing.RectangleF(0, 0, $s, $s)
        $g.DrawString("中", $font, $brush, $rect, $sf)
        # 底部黄色装饰条
        $bar = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 204, 0))
        $g.FillRectangle($bar, 0, $s - [math]::Max(2, [int]($s * 0.08)), $s, [math]::Max(2, [int]($s * 0.08)))
        $g.Dispose()
        $ms = New-Object System.IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngs += , $ms.ToArray()
        $ms.Dispose()
        $bmp.Dispose()
    }
    $fs = [System.IO.File]::Create($outPath)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([uint16]0)          # reserved
    $bw.Write([uint16]1)          # type: icon
    $bw.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i]
        $data = $pngs[$i]
        $bw.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
        $bw.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$data.Length)
        $bw.Write([uint32]$offset)
        $offset += $data.Length
    }
    foreach ($d in $pngs) { $bw.Write($d) }
    $bw.Close()
    $fs.Close()
    Write-Host "图标已生成: $outPath"
}

# ---------- 2. 编译 ----------
$compiler = @(
    (Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey\v2\Compiler\Ahk2Exe.exe"),
    (Join-Path $env:ProgramFiles "AutoHotkey\v2\Compiler\Ahk2Exe.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $compiler) {
    Write-Error "未找到 Ahk2Exe 编译器，请先安装 AutoHotkey v2: https://www.autohotkey.com/"
    exit 1
}
if (-not (Test-Path $scriptPath)) {
    Write-Error "未找到 $scriptPath"
    exit 1
}
if (-not (Test-Path $iconPath)) {
    New-AppIcon $iconPath
}

Write-Host "正在编译: $scriptPath"
& $compiler /in $scriptPath /out $exePath /icon $iconPath
if (Test-Path $exePath) {
    Write-Host "编译完成: $exePath"
} else {
    Write-Error "编译失败，请检查 Ahk2Exe 输出"
    exit 1
}
