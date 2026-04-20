<#
.SYNOPSIS
    切出同步脚本（Windows）。
    将 .workbuddy/ 镜像到同步目标并写入锁文件。
.PARAMETER Workspace
    工作区根目录路径
.PARAMETER DeviceId
    当前设备 ID
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

if (-not (Test-Path $configPath)) {
    Write-Host "[错误] 未找到 sync-config.yaml。" -ForegroundColor Red
    exit 1
}

$config = Read-SimpleYaml -Path $configPath
$architecture = $config["architecture"]
$relayDir = $config["relay_dir"]

Write-Host "=== 切出同步 ===" -ForegroundColor Cyan
Write-Host "设备：$DeviceId"
Write-Host "架构：$architecture"
Write-Host ""

$localWB = Join-Path $Workspace ".workbuddy"
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"

# --- 架构 A：中转目录 ---
if ($architecture -eq "relay") {
    $targetDir = Join-Path $Workspace "$relayDir\$DeviceId"
    
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    
    Write-Host "正在将 .workbuddy 镜像到中转目录..." -ForegroundColor Green
    $robocopyArgs = @($localWB, $targetDir, "/MIR", "/E", "/R:1", "/W:1", "/NFL", "/NDL")
    robocopy @robocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        Write-Host "[错误] robocopy 失败（退出码：$LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "镜像完成：$targetDir" -ForegroundColor Green
}

# --- 架构 B：直接同步 ---
elseif ($architecture -eq "direct") {
    $lockPath = Join-Path $localWB ".sync-lock"
    $lockContent = @"
device: "$DeviceId"
timestamp: "$timestamp"
"@
    Set-Content -Path $lockPath -Value $lockContent -Encoding UTF8
    Write-Host "锁文件已写入。" -ForegroundColor Green
    Write-Host "云服务将自动同步 .workbuddy/ 目录。"
}

# --- 架构 C：Git ---
elseif ($architecture -eq "git") {
    Push-Location $localWB
    try {
        Write-Host "正在提交并推送..." -ForegroundColor Green
        git add -A
        $commitMsg = "sync-out: $DeviceId at $timestamp"
        git commit -m $commitMsg --allow-empty 2>&1
        git push 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[警告] 推送失败，尝试先拉取..." -ForegroundColor Yellow
            git pull --rebase 2>&1
            git push 2>&1
        }
        
        Write-Host "Git 推送完成。" -ForegroundColor Green
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
Write-Host "=== 切出同步完成 ===" -ForegroundColor Cyan
Write-Host "设备：$DeviceId"
Write-Host "时间：$timestamp"
Write-Host "状态：✅ 已同步" -ForegroundColor Green
