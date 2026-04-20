# 架构 A：中转目录模式

适用于**不支持**同步点号文件夹的服务（群晖 Synology Drive、iCloud Drive）。

## 工作原理

每台设备将自己的 `.workbuddy/` 写入共享中转目录的专属子目录。各设备永远不会写同一个文件，从设计上消除冲突。

```
workspace/
├── .workbuddy/              ← 本地 AI 记忆（云服务不同步）
├── sync-relay/              ← 被云服务同步
│   ├── 办公室/              ← 办公室设备的 .workbuddy 镜像
│   │   ├── memory/
│   │   ├── plans/
│   │   └── ...
│   ├── 家里/                ← 家里设备的 .workbuddy 镜像
│   │   ├── memory/
│   │   └── ...
│   └── 笔记本/              ← 笔记本设备的 .workbuddy 镜像
│       ├── memory/
│       └── ...
└── ...
```

**核心原则**：每台设备只写 `sync-relay/{自己的设备ID}/`。切入时读取其他所有设备的子目录。

## 切入命令

### Windows (PowerShell)
```powershell
# 遍历其他设备目录，复制到本地进行比较
$config = Get-Content "$workspace\.workbuddy\sync-config.yaml" -Raw
# 解析配置获取设备列表...

foreach ($device in $otherDevices) {
    $src = "$workspace\sync-relay\$($device.id)"
    if (Test-Path $src) {
        # 与本地 .workbuddy 比较并合并
        robocopy "$src" "$workspace\.workbuddy" /E /XO /R:1 /W:1
    }
}
```

### macOS/Linux (Bash)
```bash
for device_dir in "$workspace/sync-relay"/*/; do
    device_id=$(basename "$device_dir")
    if [ "$device_id" != "$current_device" ] && [ -d "$device_dir" ]; then
        # 比较并合并
        rsync -av --update "$device_dir" "$workspace/.workbuddy/"
    fi
done
```

## 切出命令

### Windows
```powershell
robocopy "$workspace\.workbuddy" "$workspace\sync-relay\$deviceId" /MIR /E /R:1 /W:1
```

### macOS/Linux
```bash
rsync -av --delete "$workspace/.workbuddy/" "$workspace/sync-relay/$device_id/"
```

## 多设备（≥3台）合并策略

当多台设备都有变更时：

1. 列出当前设备之外的所有设备子目录
2. 按最后修改时间排序（最新优先）
3. 对每台设备，逐文件比较：
   - 文件只存在于远端 → 复制到本地
   - 两边都有，远端更新 → 复制到本地
   - 两边都有，本地更新 → 保留本地
   - 两台以上远端设备对同一文件做了不同修改 → 展示 diff 让用户选择
4. 合并完成后进入变更分类（Step 3）

## 中转目录命名

- 默认：`sync-relay`
- 用户可在初始化时自定义（如 `_sync`、`sync-bridge`）
- ⚠️ **不能**以 `.` 开头——过滤点号文件夹的云服务会跳过它
- 应简短且含义自明
