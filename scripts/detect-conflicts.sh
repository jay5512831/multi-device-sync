#!/usr/bin/env bash
# 冲突检测脚本（macOS/Linux）
# 扫描 .workbuddy/ 目录下的同步冲突副本文件。
# 支持：Syncthing、OneDrive、Dropbox、Google Drive、群晖。
#
# 用法：./detect-conflicts.sh [目标目录]

set -euo pipefail

TARGET_DIR="${1:-.}"

echo "正在扫描冲突文件：$TARGET_DIR"
echo ""

# 查找所有冲突文件
CONFLICTS=$(find "$TARGET_DIR" -type f \( \
    -name "*.sync-conflict-*" -o \
    -name "* (1).*" -o \
    -name "* (2).*" -o \
    -name "* (3).*" -o \
    -name "*conflicted copy*" -o \
    -name "*SynologyDrive conflict*" \
\) 2>/dev/null || true)

if [ -z "$CONFLICTS" ]; then
    echo "未发现冲突文件。"
    exit 0
fi

COUNT=$(echo "$CONFLICTS" | wc -l | xargs)
echo "发现 $COUNT 个冲突文件："
echo ""

echo "$CONFLICTS" | while IFS= read -r file; do
    [ -z "$file" ] && continue
    
    # 获取相对路径
    REL_PATH="${file#$TARGET_DIR/}"
    
    # 文件信息
    if command -v stat &>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SIZE=$(stat -f%z "$file" 2>/dev/null || echo "?")
            MODIFIED=$(stat -f"%Sm" -t"%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "?")
        else
            SIZE=$(stat --format=%s "$file" 2>/dev/null || echo "?")
            MODIFIED=$(stat --format='%y' "$file" 2>/dev/null | cut -d. -f1 || echo "?")
        fi
    else
        SIZE="?"
        MODIFIED="?"
    fi
    
    # 人类可读的大小
    if [ "$SIZE" != "?" ] && [ "$SIZE" -gt 1024 ] 2>/dev/null; then
        HR_SIZE="$((SIZE / 1024)) KB"
    else
        HR_SIZE="${SIZE} B"
    fi
    
    echo "  $REL_PATH"
    echo "    大小：$HR_SIZE | 修改时间：$MODIFIED"
    echo ""
done

echo "请在继续之前解决这些冲突。"
echo "对每个冲突：决定保留原文件还是冲突副本。"
# 退出码 1 表示有冲突（bash 退出码范围 0-255，用 COUNT 可能溢出）
exit 1
