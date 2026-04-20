# collect-diagnostics.ps1
# 采集同步诊断信息，用于问题反馈报告
# 用法：pwsh collect-diagnostics.ps1 [-WorkspaceRoot <路径>]
# 不采集任何敏感信息（密码、token、API key）

param(
    [string]$WorkspaceRoot = (Get-Location).Path
)

$ErrorActionPreference = "Continue"

Write-Host "===== 同步诊断信息采集 =====" -ForegroundColor Cyan
Write-Host ""

# --- 1. 操作系统 ---
Write-Host "## OS 信息" -ForegroundColor Yellow
$osInfo = Get-CimInstance Win32_OperatingSystem
Write-Host "OS: $($osInfo.Caption) $($osInfo.Version)"
Write-Host "架构: $env:PROCESSOR_ARCHITECTURE"
Write-Host "计算机名: $env:COMPUTERNAME"
Write-Host ""

# --- 2. Shell 版本 ---
Write-Host "## Shell 信息" -ForegroundColor Yellow
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host ""

# --- 3. Skill 版本 ---
Write-Host "## Skill 版本" -ForegroundColor Yellow
$skillDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$skillMd = Join-Path $skillDir "SKILL.md"
if (Test-Path $skillMd) {
    $skillFile = Get-Item $skillMd
    Write-Host "SKILL.md 修改日期: $($skillFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "SKILL.md 大小: $($skillFile.Length) bytes"
} else {
    Write-Host "SKILL.md: 未找到"
}
Write-Host ""

# --- 4. 工作区信息 ---
Write-Host "## 工作区" -ForegroundColor Yellow
Write-Host "工作区路径: $WorkspaceRoot"
$wbDir = Join-Path $WorkspaceRoot ".workbuddy"
if (Test-Path $wbDir) {
    Write-Host ".workbuddy 目录: 存在"
} else {
    Write-Host ".workbuddy 目录: 不存在"
}
Write-Host ""

# --- 5. sync-config.yaml 状态 ---
Write-Host "## sync-config.yaml" -ForegroundColor Yellow
$syncConfig = Join-Path $wbDir "sync-config.yaml"
if (Test-Path $syncConfig) {
    $configFile = Get-Item $syncConfig
    Write-Host "状态: 存在"
    Write-Host "修改日期: $($configFile.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host "大小: $($configFile.Length) bytes"
} else {
    Write-Host "状态: 不存在"
}
Write-Host ""

# --- 6. sync-lock 状态 ---
Write-Host "## sync-lock" -ForegroundColor Yellow
$syncLock = Join-Path $wbDir "sync-lock"
if (Test-Path $syncLock) {
    Write-Host "状态: 存在"
    Write-Host "内容:"
    Get-Content $syncLock | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "状态: 不存在"
}
Write-Host ""

# --- 7. .identity-snapshot 状态 ---
Write-Host "## .identity-snapshot" -ForegroundColor Yellow
$idSnap = Join-Path $wbDir ".identity-snapshot"
if (Test-Path $idSnap) {
    Write-Host "状态: 存在"
    Write-Host "内容:"
    Get-Content $idSnap | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "状态: 不存在"
}
Write-Host ""

# --- 8. 中转目录结构（如果架构 A） ---
Write-Host "## 中转目录 / 同步目录结构" -ForegroundColor Yellow

# 尝试从 sync-config.yaml 读取 relay_dir
$relayDir = $null
if (Test-Path $syncConfig) {
    $configContent = Get-Content $syncConfig -Raw
    if ($configContent -match 'relay_dir:\s*"?([^"\r\n]+)"?') {
        $relayDir = $Matches[1].Trim()
    }
}

if ($relayDir) {
    $relayPath = Join-Path $WorkspaceRoot $relayDir
    if (Test-Path $relayPath) {
        Write-Host "中转目录路径: $relayPath"
        Write-Host "结构（2 层深度）:"
        # 列出 2 层深度的目录结构
        Get-ChildItem $relayPath -Depth 1 -ErrorAction SilentlyContinue | ForEach-Object {
            $indent = ""
            $rel = $_.FullName.Substring($relayPath.Length + 1)
            $depth = ($rel.Split([IO.Path]::DirectorySeparatorChar)).Count - 1
            $indent = "  " * $depth
            $icon = if ($_.PSIsContainer) { "[DIR]" } else { "" }
            Write-Host "  $indent$icon $($_.Name)"
        }
    } else {
        Write-Host "中转目录路径: $relayPath（不存在）"
    }
} else {
    Write-Host "未检测到中转目录配置（可能是架构 B/C）"
    # 列出 .workbuddy 的直接子目录
    if (Test-Path $wbDir) {
        Write-Host ".workbuddy 子目录结构:"
        Get-ChildItem $wbDir -Depth 1 -ErrorAction SilentlyContinue | ForEach-Object {
            $icon = if ($_.PSIsContainer) { "[DIR]" } else { "" }
            Write-Host "  $icon $($_.Name)"
        }
    }
}
Write-Host ""

# --- 9. SOUL.md / IDENTITY.md 状态 ---
Write-Host "## 人设文件" -ForegroundColor Yellow
$soulMd = Join-Path $WorkspaceRoot "SOUL.md"
$identityMd = Join-Path $WorkspaceRoot "IDENTITY.md"
if (Test-Path $soulMd) {
    $f = Get-Item $soulMd
    Write-Host "SOUL.md: 存在 (修改: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')), 大小: $($f.Length) bytes)"
} else {
    Write-Host "SOUL.md: 不存在"
}
if (Test-Path $identityMd) {
    $f = Get-Item $identityMd
    Write-Host "IDENTITY.md: 存在 (修改: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')), 大小: $($f.Length) bytes)"
} else {
    Write-Host "IDENTITY.md: 不存在"
}
Write-Host ""

# --- 10. Git 状态（如果架构 C）---
Write-Host "## Git 状态" -ForegroundColor Yellow
$gitDir = Join-Path $wbDir ".git"
if (Test-Path $gitDir) {
    Push-Location $wbDir
    Write-Host "Git 仓库: 存在"
    try {
        $branch = git rev-parse --abbrev-ref HEAD 2>&1
        Write-Host "当前分支: $branch"
        $status = git status --short 2>&1
        if ($status) {
            Write-Host "未提交变更:"
            $status | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "工作区干净（无未提交变更）"
        }
    } catch {
        Write-Host "Git 命令执行失败: $_"
    }
    Pop-Location
} else {
    Write-Host "Git 仓库: 不存在（非架构 C）"
}
Write-Host ""

Write-Host "===== 采集完成 =====" -ForegroundColor Cyan
