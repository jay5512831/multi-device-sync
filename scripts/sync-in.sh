#!/usr/bin/env bash
# 切入同步脚本（macOS/Linux）
# 读取 sync-config.yaml，从其他设备拉取数据，检测冲突。
#
# 用法：./sync-in.sh <工作区路径> <设备ID>

set -euo pipefail

WORKSPACE="$1"
DEVICE_ID="$2"
CONFIG_PATH="$WORKSPACE/.workbuddy/sync-config.yaml"

# --- YAML 读取器：只读取顶层标量键值（跳过缩进/嵌套行）---
yaml_get() {
    local key="$1" file="$2"
    grep -E "^${key}:" "$file" | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"[[:space:]]*$//' | sed 's/[[:space:]]*#.*//' | xargs
}

# --- 读取配置 ---
if [ ! -f "$CONFIG_PATH" ]; then
    echo "[错误] 未找到 sync-config.yaml：$CONFIG_PATH"
    echo "请先运行初始化问卷。"
    exit 1
fi

ARCHITECTURE=$(yaml_get "architecture" "$CONFIG_PATH")
RELAY_DIR=$(yaml_get "relay_dir" "$CONFIG_PATH")

echo "=== 切入同步 ==="
echo "设备：$DEVICE_ID"
echo "架构：$ARCHITECTURE"
echo ""

# --- 架构 A：中转目录 ---
if [ "$ARCHITECTURE" = "relay" ]; then
    RELAY_PATH="$WORKSPACE/$RELAY_DIR"
    
    if [ ! -d "$RELAY_PATH" ]; then
        echo "[提示] 中转目录不存在，首次使用。"
        echo "切出后其他设备才能获取你的数据。"
        exit 0
    fi
    
    LOCAL_WB="$WORKSPACE/.workbuddy"
    CHANGED=0
    
    for device_dir in "$RELAY_PATH"/*/; do
        [ ! -d "$device_dir" ] && continue
        dir_name=$(basename "$device_dir")
        [ "$dir_name" = "$DEVICE_ID" ] && continue
        
        echo "正在读取设备：$dir_name..."
        rsync -av --update "$device_dir" "$LOCAL_WB/" 2>/dev/null | tail -n +2 | head -20
        CHANGED=$((CHANGED + 1))
    done
    
    if [ "$CHANGED" -eq 0 ]; then
        echo "[提示] 未发现其他设备数据，首次使用。"
        exit 0
    fi
    
    echo ""
    echo "=== 同步摘要 ==="
    echo "同步来源设备数：$CHANGED"

# --- 架构 B：直接同步 ---
elif [ "$ARCHITECTURE" = "direct" ]; then
    LOCK_PATH="$WORKSPACE/.workbuddy/sync-lock"
    
    if [ -f "$LOCK_PATH" ]; then
        LOCK_DEVICE=$(yaml_get "device" "$LOCK_PATH")
        LOCK_TS=$(yaml_get "timestamp" "$LOCK_PATH")
        
        if [ "$LOCK_DEVICE" = "$DEVICE_ID" ]; then
            echo "[提示] 本设备的残留锁，正在清理。"
            rm -f "$LOCK_PATH"
        else
            LOCK_EPOCH=$(date -d "$LOCK_TS" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$LOCK_TS" +%s 2>/dev/null || echo 0)
            NOW_EPOCH=$(date +%s)
            AGE_HOURS=$(( (NOW_EPOCH - LOCK_EPOCH) / 3600 ))
            
            if [ "$AGE_HOURS" -gt 24 ]; then
                echo "[警告] 设备 '$LOCK_DEVICE' 的过期锁（${AGE_HOURS}小时前）。"
                echo "继续执行。"
                rm -f "$LOCK_PATH"
            else
                echo "[提示] 设备 '$LOCK_DEVICE' 刚切出不久。"
                echo "等待 10 秒让云服务完成同步..."
                sleep 10
            fi
        fi
    fi
    
    # 运行冲突检测
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    DETECT_SCRIPT="$SCRIPT_DIR/detect-conflicts.sh"
    if [ -x "$DETECT_SCRIPT" ]; then
        echo ""
        echo "正在扫描冲突文件..."
        "$DETECT_SCRIPT" "$WORKSPACE/.workbuddy"
    fi
    
    echo ""
    echo "=== 切入完成（直接同步模式）==="
    echo "云服务负责文件同步，冲突扫描已完成。"

# --- 架构 C：Git ---
elif [ "$ARCHITECTURE" = "git" ]; then
    cd "$WORKSPACE/.workbuddy"
    
    echo "正在拉取远程仓库..."
    if git pull --rebase; then
        echo "Git 拉取成功。"
    else
        echo "[警告] Git 拉取出现问题，请检查合并冲突。"
        git diff --name-only --diff-filter=U
    fi
    
    echo ""
    echo "近期同步记录："
    git log --oneline -5

else
    echo "[错误] 未知架构：$ARCHITECTURE"
    exit 1
fi

echo ""
echo "切入同步完成，可以开始工作了。"
