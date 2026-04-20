#!/usr/bin/env bash
# 切出同步脚本（macOS/Linux）
# 将 .workbuddy/ 镜像到同步目标并写入锁文件。
#
# 用法：./sync-out.sh <工作区路径> <设备ID>

set -euo pipefail

WORKSPACE="$1"
DEVICE_ID="$2"
CONFIG_PATH="$WORKSPACE/.workbuddy/sync-config.yaml"

# --- YAML 读取器：只读取顶层标量键值 ---
yaml_get() {
    local key="$1" file="$2"
    grep -E "^${key}:" "$file" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"[[:space:]]*$//' | sed 's/[[:space:]]*#.*//' | xargs
}

if [ ! -f "$CONFIG_PATH" ]; then
    echo "[错误] 未找到 sync-config.yaml。"
    exit 1
fi

ARCHITECTURE=$(yaml_get "architecture" "$CONFIG_PATH")
RELAY_DIR=$(yaml_get "relay_dir" "$CONFIG_PATH")

LOCAL_WB="$WORKSPACE/.workbuddy"
TIMESTAMP=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z)

echo "=== 切出同步 ==="
echo "设备：$DEVICE_ID"
echo "架构：$ARCHITECTURE"
echo ""

# --- 架构 A：中转目录 ---
if [ "$ARCHITECTURE" = "relay" ]; then
    TARGET_DIR="$WORKSPACE/$RELAY_DIR/$DEVICE_ID"
    mkdir -p "$TARGET_DIR"
    
    echo "正在将 .workbuddy 镜像到中转目录..."
    rsync -av --delete "$LOCAL_WB/" "$TARGET_DIR/"
    echo "镜像完成：$TARGET_DIR"

# --- 架构 B：直接同步 ---
elif [ "$ARCHITECTURE" = "direct" ]; then
    LOCK_PATH="$LOCAL_WB/sync-lock"
    cat > "$LOCK_PATH" << EOF
device: "$DEVICE_ID"
timestamp: "$TIMESTAMP"
EOF
    echo "锁文件已写入。"
    echo "云服务将自动同步 .workbuddy/ 目录。"

# --- 架构 C：Git ---
elif [ "$ARCHITECTURE" = "git" ]; then
    cd "$LOCAL_WB"
    
    echo "正在提交并推送..."
    git add -A
    COMMIT_MSG="sync-out: $DEVICE_ID at $TIMESTAMP"
    git commit -m "$COMMIT_MSG" --allow-empty
    
    if ! git push; then
        echo "[警告] 推送失败，尝试先拉取..."
        git pull --rebase
        git push
    fi
    
    echo "Git 推送完成。"

else
    echo "[错误] 未知架构：$ARCHITECTURE"
    exit 1
fi

echo ""
echo "=== 切出同步完成 ==="
echo "设备：$DEVICE_ID"
echo "时间：$TIMESTAMP"
echo "状态：✅ 已同步"
