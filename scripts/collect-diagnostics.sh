#!/usr/bin/env bash
# collect-diagnostics.sh
# 采集同步诊断信息，用于问题反馈报告
# 用法：bash collect-diagnostics.sh [工作区路径]
# 不采集任何敏感信息（密码、token、API key）

set -euo pipefail

WORKSPACE_ROOT="${1:-$(pwd)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
WB_DIR="$WORKSPACE_ROOT/.workbuddy"

echo "===== 同步诊断信息采集 ====="
echo ""

# --- 1. 操作系统 ---
echo "## OS 信息"
if [[ "$(uname)" == "Darwin" ]]; then
    echo "OS: macOS $(sw_vers -productVersion 2>/dev/null || echo '未知')"
    echo "架构: $(uname -m)"
else
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "OS: $PRETTY_NAME"
    else
        echo "OS: $(uname -s) $(uname -r)"
    fi
    echo "架构: $(uname -m)"
fi
echo "主机名: $(hostname)"
echo ""

# --- 2. Shell 版本 ---
echo "## Shell 信息"
echo "Shell: $SHELL"
if command -v bash &>/dev/null; then
    echo "Bash: $(bash --version | head -1)"
fi
if command -v zsh &>/dev/null; then
    echo "Zsh: $(zsh --version 2>/dev/null || echo '未知')"
fi
echo ""

# --- 3. Skill 版本 ---
echo "## Skill 版本"
SKILL_MD="$SKILL_DIR/SKILL.md"
if [ -f "$SKILL_MD" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        mod_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$SKILL_MD")
        file_size=$(stat -f "%z" "$SKILL_MD")
    else
        mod_date=$(stat -c "%y" "$SKILL_MD" | cut -d'.' -f1)
        file_size=$(stat -c "%s" "$SKILL_MD")
    fi
    echo "SKILL.md 修改日期: $mod_date"
    echo "SKILL.md 大小: $file_size bytes"
else
    echo "SKILL.md: 未找到"
fi
echo ""

# --- 4. 工作区信息 ---
echo "## 工作区"
echo "工作区路径: $WORKSPACE_ROOT"
if [ -d "$WB_DIR" ]; then
    echo ".workbuddy 目录: 存在"
else
    echo ".workbuddy 目录: 不存在"
fi
echo ""

# --- 5. sync-config.yaml 状态 ---
echo "## sync-config.yaml"
SYNC_CONFIG="$WB_DIR/sync-config.yaml"
if [ -f "$SYNC_CONFIG" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
        mod_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$SYNC_CONFIG")
        file_size=$(stat -f "%z" "$SYNC_CONFIG")
    else
        mod_date=$(stat -c "%y" "$SYNC_CONFIG" | cut -d'.' -f1)
        file_size=$(stat -c "%s" "$SYNC_CONFIG")
    fi
    echo "状态: 存在"
    echo "修改日期: $mod_date"
    echo "大小: $file_size bytes"
else
    echo "状态: 不存在"
fi
echo ""

# --- 6. sync-lock 状态 ---
echo "## sync-lock"
SYNC_LOCK="$WB_DIR/sync-lock"
if [ -f "$SYNC_LOCK" ]; then
    echo "状态: 存在"
    echo "内容:"
    sed 's/^/  /' "$SYNC_LOCK"
else
    echo "状态: 不存在"
fi
echo ""

# --- 7. .identity-snapshot 状态 ---
echo "## .identity-snapshot"
ID_SNAP="$WB_DIR/.identity-snapshot"
if [ -f "$ID_SNAP" ]; then
    echo "状态: 存在"
    echo "内容:"
    sed 's/^/  /' "$ID_SNAP"
else
    echo "状态: 不存在"
fi
echo ""

# --- 8. 中转目录结构 ---
echo "## 中转目录 / 同步目录结构"
RELAY_DIR=""
if [ -f "$SYNC_CONFIG" ]; then
    RELAY_DIR=$(sed -n 's/^relay_dir:[[:space:]]*"\?\([^"[:space:]]*\)"\?/\1/p' "$SYNC_CONFIG" 2>/dev/null || true)
fi

if [ -n "$RELAY_DIR" ]; then
    RELAY_PATH="$WORKSPACE_ROOT/$RELAY_DIR"
    if [ -d "$RELAY_PATH" ]; then
        echo "中转目录路径: $RELAY_PATH"
        echo "结构（2 层深度）:"
        if command -v tree &>/dev/null; then
            tree -L 2 "$RELAY_PATH" 2>/dev/null | sed 's/^/  /'
        else
            find "$RELAY_PATH" -maxdepth 2 -print 2>/dev/null | sed "s|$RELAY_PATH/||" | sed 's/^/  /'
        fi
    else
        echo "中转目录路径: $RELAY_PATH（不存在）"
    fi
else
    echo "未检测到中转目录配置（可能是架构 B/C）"
    if [ -d "$WB_DIR" ]; then
        echo ".workbuddy 子目录结构:"
        if command -v tree &>/dev/null; then
            tree -L 1 "$WB_DIR" 2>/dev/null | sed 's/^/  /'
        else
            ls -1 "$WB_DIR" 2>/dev/null | sed 's/^/  /'
        fi
    fi
fi
echo ""

# --- 9. SOUL.md / IDENTITY.md 状态 ---
echo "## 人设文件"
SOUL_MD="$WORKSPACE_ROOT/SOUL.md"
IDENTITY_MD="$WORKSPACE_ROOT/IDENTITY.md"
for f_path in "$SOUL_MD" "$IDENTITY_MD"; do
    f_name=$(basename "$f_path")
    if [ -f "$f_path" ]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            mod_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$f_path")
            file_size=$(stat -f "%z" "$f_path")
        else
            mod_date=$(stat -c "%y" "$f_path" | cut -d'.' -f1)
            file_size=$(stat -c "%s" "$f_path")
        fi
        echo "$f_name: 存在 (修改: $mod_date, 大小: $file_size bytes)"
    else
        echo "$f_name: 不存在"
    fi
done
echo ""

# --- 10. Git 状态 ---
echo "## Git 状态"
GIT_DIR="$WB_DIR/.git"
if [ -d "$GIT_DIR" ]; then
    echo "Git 仓库: 存在"
    cd "$WB_DIR"
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "未知")
    echo "当前分支: $branch"
    status=$(git status --short 2>/dev/null || true)
    if [ -n "$status" ]; then
        echo "未提交变更:"
        echo "$status" | sed 's/^/  /'
    else
        echo "工作区干净（无未提交变更）"
    fi
else
    echo "Git 仓库: 不存在（非架构 C）"
fi
echo ""

echo "===== 采集完成 ====="
