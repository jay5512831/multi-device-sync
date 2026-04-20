# 冲突文件命名模式

用于检测各同步服务产生的冲突副本的正则表达式。

## 各服务的模式

### Syncthing
```
模式：.sync-conflict-日期-时间-设备ID
示例：MEMORY.sync-conflict-20260420-180000-ABC1234.md
正则：\.sync-conflict-\d{8}-\d{6}-[A-Z0-9]+
```

### OneDrive
```
模式：文件名 (数字).扩展名
示例：MEMORY (1).md, MEMORY (2).md
正则：.+ \(\d+\)\.[^.]+$
```

### Dropbox
```
模式：文件名 (用户名's conflicted copy 日期).扩展名
示例：MEMORY (John's conflicted copy 2026-04-20).md
正则：.+ \(.+'s conflicted copy \d{4}-\d{2}-\d{2}\)\.[^.]+$
```

### Google Drive
```
模式：文件名 (数字).扩展名（与 OneDrive 相同）
示例：MEMORY (1).md
正则：.+ \(\d+\)\.[^.]+$
```

### 群晖 Synology Drive
```
模式：文件名 (SynologyDrive conflict).扩展名
示例：MEMORY (SynologyDrive conflict).md
正则：.+ \(SynologyDrive conflict\)\.[^.]+$
```

### iCloud Drive
```
模式：文件名 数字.扩展名（不常见，iCloud 通常自动合并）
很少产生可见的冲突文件——通常内部解决
```

## 综合检测脚本逻辑

### PowerShell (Windows)

```powershell
$patterns = @(
    '\.sync-conflict-\d{8}-\d{6}-[A-Z0-9]+',     # Syncthing
    ' \(\d+\)\.[^.]+$',                             # OneDrive / Google Drive
    " \(.+'s conflicted copy \d{4}-\d{2}-\d{2}\)", # Dropbox
    ' \(SynologyDrive conflict\)'                    # 群晖
)

$combinedPattern = ($patterns -join '|')

Get-ChildItem -Path $targetDir -Recurse -File |
    Where-Object { $_.Name -match $combinedPattern }
```

### Bash (macOS/Linux)

```bash
find "$target_dir" -type f \( \
    -name "*.sync-conflict-*" -o \
    -regex ".* ([0-9]+)\.[^.]*" -o \
    -name "*conflicted copy*" -o \
    -name "*SynologyDrive conflict*" \
\)
```

## 解决策略

对每个检测到的冲突：

1. **找到原文件** —— 去掉冲突后缀得到原始文件名
2. **比较修改时间** —— 较新的通常是要保留的
3. **显示差异**（如果是文本文件）—— 让用户看到具体区别
4. **询问用户** —— 保留原文件 / 保留冲突副本 / 手动合并
5. **清理** —— 解决后删除冲突副本
6. **记录** —— 在当天的记忆日志中记录解决情况
