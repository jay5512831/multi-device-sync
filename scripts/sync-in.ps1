<#
.SYNOPSIS
    切入同步脚本（Windows）。
    读取 sync-config.yaml，从其他设备拉取数据，检测冲突。
.DESCRIPTION
    架构 A（中转目录）：从其他设备的中转子目录复制
    架构 B（直接同步）：检查 sync-lock 并运行冲突检测
    架构 C（Git）：执行 git pull --rebase
.PARAMETER Workspace
    工作区根目录路径（包含 .workbuddy/）
.PARAMETER DeviceId
    当前设备 ID（来自 sync-config.yaml）
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Workspace,
    
    [Parameter(Mandatory=$true)]
    [string]$DeviceId
)

$ErrorActionPreference = "Stop"
$configPath = Join-Path $Workspace ".workbuddy\sync-config.yaml"

# --- YAML 解析器：只读取顶层标量键值 ---
# 跳过缩进行（嵌套的 devices、triggers 等由 AI 在 SKILL.md 流程中处理）
function Read-SimpleYaml {
    param([string]$Path)
    $result = @{}
    foreach ($line in (Get-Content $Path -Encoding UTF8)) {
        if ($line -match '^\s*$' -or $line -match '^\s*#' -or $line -match '^\s+') { continue }
        if ($line -match '^(\w+):\s*"([^"]*)"' ) {
            $result[$Matches[1]] = $Matches[2]
        }
        elseif ($line -match '^(\w+):\s*([^#\[\{]+)') {
            $val = $Matches[2].Trim().Trim('"')
            if ($val -ne '' -and $val -ne '|') {
                $result[$Matches[1]] = $val
            }
        }
    }
    return $result
}

# --- 读取配置 ---
if (-not (Test-Path $configPath)) {
    Write-Host "[错误] 未找到 sync-config.yaml：$configPath" -ForegroundColor Red
    Write-Host "请先运行初始化问卷。"
    exit 1
}

$config = Read-SimpleYaml -Path $configPath
$architecture = $config["architecture"]
$relayDir = $config["relay_dir"]

Write-Host "=== 切入同步 ===" -ForegroundColor Cyan
Write-Host "设备：$DeviceId"
Write-Host "架构：$architecture"
Write-Host ""

# --- 架构 A：中转目录 ---
if ($architecture -eq "relay") {
    $relayPath = Join-Path $Workspace $relayDir
    if (-not (Test-Path $relayPath)) {
        Write-Host "[提示] 中转目录不存在，首次使用。" -ForegroundColor Yellow
        Write-Host "切出后其他设备才能获取你的数据。"
        exit 0
    }
    
    $otherDevices = Get-ChildItem -Path $relayPath -Directory | Where-Object { $_.Name -ne $DeviceId }
    if ($otherDevices.Count -eq 0) {
        Write-Host "[提示] 未发现其他设备数据，首次使用。" -ForegroundColor Yellow
        exit 0
    }
    
    $localWB = Join-Path $Workspace ".workbuddy"
    $changedFiles = @()
    
    foreach ($deviceDir in $otherDevices) {
        Write-Host "正在读取设备：$($deviceDir.Name)..." -ForegroundColor Green
        $src = $deviceDir.FullName
        
        # 先收集变更列表（在复制之前比较时间戳）
        $files = Get-ChildItem -Path $src -Recurse -File
        foreach ($f in $files) {
            $relativePath = $f.FullName.Substring($src.Length)
            $localFile = Join-Path $localWB $relativePath
            if (-not (Test-Path $localFile) -or ($f.LastWriteTime -gt (Get-Item $localFile).LastWriteTime)) {
                $changedFiles += @{
                    Path = $relativePath
                    Source = $deviceDir.Name
                    Time = $f.LastWriteTime
                }
            }
        }
        
        # 执行复制（只复制较新的文件）
        $robocopyArgs = @($src, $localWB, "/E", "/XO", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS")
        robocopy @robocopyArgs | Out-Null
        # robocopy 退出码：0-7 = 成功/部分成功，>=8 = 错误
        if ($LASTEXITCODE -ge 8) {
            Write-Host "[警告] robocopy 报告错误（退出码：$LASTEXITCODE），设备 $($deviceDir.Name)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "=== 同步摘要 ===" -ForegroundColor Cyan
    Write-Host "同步来源设备数：$($otherDevices.Count)"
    Write-Host "更新文件数：$($changedFiles.Count)"
    if ($changedFiles.Count -gt 0) {
        Write-Host ""
        Write-Host "变更文件：" -ForegroundColor Yellow
        foreach ($cf in $changedFiles) {
            Write-Host "  [$($cf.Source)] $($cf.Path)"
        }
    }
}

# --- 架构 B：直接同步 ---
elseif ($architecture -eq "direct") {
    $lockPath = Join-Path $Workspace ".workbuddy\sync-lock"
    
    # 检查锁文件
    if (Test-Path $lockPath) {
        $lockContent = Get-Content $lockPath -Raw -Encoding UTF8
        $lockDevice = ""
        $lockTime = [DateTime]::MinValue
        
        foreach ($line in $lockContent -split "`n") {
            if ($line -match 'device:\s*"?([^"]+)"?') { $lockDevice = $Matches[1].Trim() }
            if ($line -match 'timestamp:\s*"?([^"]+)"?') { 
                $lockTime = [DateTime]::Parse($Matches[1].Trim())
            }
        }
        
        $age = (Get-Date) - $lockTime
        
        if ($lockDevice -eq $DeviceId) {
            Write-Host "[提示] 本设备的残留锁，正在清理。" -ForegroundColor Yellow
            Remove-Item $lockPath -Force
        }
        elseif ($age.TotalHours -gt 24) {
            Write-Host "[警告] 设备 '$lockDevice' 的过期锁（$([math]::Round($age.TotalHours, 1)) 小时前）。" -ForegroundColor Yellow
            Write-Host "继续执行。"
            Remove-Item $lockPath -Force
        }
        else {
            Write-Host "[提示] 设备 '$lockDevice' 在 $([math]::Round($age.TotalMinutes, 0)) 分钟前切出。" -ForegroundColor Green
            Write-Host "等待 10 秒让云服务完成同步..."
            Start-Sleep -Seconds 10
        }
    }
    
    # 运行冲突检测
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $detectScript = Join-Path $scriptDir "detect-conflicts.ps1"
    if (Test-Path $detectScript) {
        Write-Host ""
        Write-Host "正在扫描冲突文件..." -ForegroundColor Cyan
        & $detectScript -TargetDir (Join-Path $Workspace ".workbuddy")
    }
    
    Write-Host ""
    Write-Host "=== 切入完成（直接同步模式）===" -ForegroundColor Cyan
    Write-Host "云服务负责文件同步，冲突扫描已完成。"
}

# --- 架构 C：Git ---
elseif ($architecture -eq "git") {
    $wbPath = Join-Path $Workspace ".workbuddy"
    Push-Location $wbPath
    try {
        Write-Host "正在拉取远程仓库..." -ForegroundColor Green
        git pull --rebase 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[警告] Git 拉取出现问题，请检查合并冲突。" -ForegroundColor Yellow
            git diff --name-only --diff-filter=U
        }
        else {
            Write-Host "Git 拉取成功。" -ForegroundColor Green
        }
        
        # 显示其他设备的近期提交
        Write-Host ""
        Write-Host "近期同步记录：" -ForegroundColor Cyan
        git log --oneline -5
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "[错误] 未知架构：$architecture" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "切入同步完成，可以开始工作了。" -ForegroundColor Green
