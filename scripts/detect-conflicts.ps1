<#
.SYNOPSIS
    冲突检测脚本（Windows）。
    扫描 .workbuddy/ 目录下的同步冲突副本文件。
    支持：Syncthing、OneDrive、Dropbox、Google Drive、群晖。
.PARAMETER TargetDir
    要扫描的目录（默认：当前目录）
#>
param(
    [Parameter(Mandatory=$false)]
    [string]$TargetDir = "."
)

$patterns = @(
    # Syncthing：file.sync-conflict-20260420-180000-ABC1234.ext
    '\.sync-conflict-\d{8}-\d{6}-[A-Z0-9]+'
    # OneDrive / Google Drive：file (1).ext, file (2).ext
    ' \(\d+\)\.[^.]+$'
    # Dropbox：file (User's conflicted copy 2026-04-20).ext
    " \(.+'s conflicted copy \d{4}-\d{2}-\d{2}\)"
    # 群晖：file (SynologyDrive conflict).ext
    ' \(SynologyDrive conflict\)'
)

$combinedPattern = ($patterns -join '|')

$conflicts = Get-ChildItem -Path $TargetDir -Recurse -File |
    Where-Object { $_.Name -match $combinedPattern }

if ($conflicts.Count -eq 0) {
    Write-Host "未发现冲突文件。" -ForegroundColor Green
    exit 0
}

Write-Host "发现 $($conflicts.Count) 个冲突文件：" -ForegroundColor Yellow
Write-Host ""

foreach ($file in $conflicts) {
    $relativePath = $file.FullName
    if ($file.FullName.StartsWith($TargetDir)) {
        $relativePath = $file.FullName.Substring($TargetDir.Length).TrimStart('\', '/')
    }
    
    $size = if ($file.Length -gt 1024) { "$([math]::Round($file.Length / 1024, 1)) KB" } else { "$($file.Length) B" }
    $modified = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    
    Write-Host "  $relativePath" -ForegroundColor Red
    Write-Host "    大小：$size | 修改时间：$modified"
    
    # 尝试找到原文件
    $originalName = $file.Name
    $originalName = $originalName -replace '\.sync-conflict-\d{8}-\d{6}-[A-Z0-9]+', ''
    $originalName = $originalName -replace ' \(\d+\)(\.[^.]+)$', '$1'
    $originalName = $originalName -replace " \(.+'s conflicted copy \d{4}-\d{2}-\d{2}\)(\.[^.]+)$", '$1'
    $originalName = $originalName -replace ' \(SynologyDrive conflict\)(\.[^.]+)$', '$1'
    
    if ($originalName -ne $file.Name) {
        $originalPath = Join-Path $file.DirectoryName $originalName
        if (Test-Path $originalPath) {
            $origFile = Get-Item $originalPath
            $origSize = if ($origFile.Length -gt 1024) { "$([math]::Round($origFile.Length / 1024, 1)) KB" } else { "$($origFile.Length) B" }
            $origModified = $origFile.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
            Write-Host "    原文件：$originalName（大小：$origSize | 修改时间：$origModified）" -ForegroundColor Gray
        }
    }
    Write-Host ""
}

Write-Host "请在继续之前解决这些冲突。" -ForegroundColor Yellow
Write-Host "对每个冲突：决定保留原文件还是冲突副本。"
exit $conflicts.Count
