# 同步方式参考

## 对照表

| 同步方式 | 支持同步 `.xxx` 文件夹？ | 冲突处理策略 | 支持平台 | 对应架构 |
|---------|----------------------|------------|---------|---------|
| **群晖 Synology Drive** | ❌ 不支持（过滤所有点号开头的文件和文件夹） | 重命名冲突文件 | Win/Mac/Linux | A（中转目录） |
| **iCloud Drive** | ❌ 不支持（跳过点号文件） | Apple 内部合并 | Mac/Win(有限) | A（中转目录） |
| **OneDrive** | ✅ 支持 | 创建 `文件名 (1).ext` 副本 | Win/Mac/Linux | B（直接同步） |
| **Dropbox** | ✅ 支持 | 创建 `文件名 (用户名's conflicted copy 日期).ext` | Win/Mac/Linux | B（直接同步） |
| **Google Drive** | ✅ 支持 | 创建 `文件名 (1).ext` 副本 | Win/Mac/Linux | B（直接同步） |
| **Syncthing** | ✅ 支持（默认） | 重命名为 `文件名.sync-conflict-日期-设备ID.ext` | Win/Mac/Linux/Android | B（直接同步） |
| **Git** | ✅ 支持（核心功能） | 合并冲突标记 `<<<<<<<` | Win/Mac/Linux | C（Git） |
| **WebDAV** | ✅ 支持（协议层无限制） | 取决于客户端 | Win/Mac/Linux | B（直接同步） |
| **rsync / 自建服务器** | ✅ 支持 | 无内置冲突处理 | Win/Mac/Linux | B（直接同步） |

## 详细说明

### 群晖 Synology Drive
- 默认过滤规则会跳过**所有**以 `.` 开头的文件和文件夹（不只是文件夹，文件也会被跳过）
- 可在 DSM 设置中取消过滤，但不推荐（可能同步不需要的系统文件夹）
- 冲突文件命名：`文件名 (SynologyDrive conflict).ext`
- ⚠️ 中转目录中**任何需要被对方设备读到的文件**都不能以 `.` 开头

### iCloud Drive
- 明确跳过所有以 `.` 开头的文件和文件夹
- 社区确认：`.git`、`.config`、`.workbuddy` 都不会同步
- 无法通过用户设置解除此限制
- 冲突解决机制不透明（Apple 内部处理）

### OneDrive
- Windows 和 Mac 上默认同步隐藏/点号文件夹
- Linux 客户端（`abraunegg/onedrive`）有 `skip_dotfiles` 选项（默认关闭）
- 冲突副本命名：`文件名 (1).ext`、`文件名 (2).ext` 等

### Dropbox
- 同步一切，包括点号文件夹
- 冲突副本命名：`文件名 (用户名's conflicted copy 日期).ext`
- 智能同步可能延迟不常访问的文件

### Google Drive
- 会同步点号文件夹（已知问题：同步 `.git` 可能损坏仓库）
- 冲突副本命名：`文件名 (1).ext`
- 流模式 vs 镜像模式会影响行为

### Syncthing
- 默认同步一切，可通过 `.stignore` 自定义
- 冲突文件：`文件名.sync-conflict-YYYYMMDD-HHMMSS-设备ID.ext`
- 支持类似 `.gitignore` 的忽略规则
- 去中心化——不需要云服务器

### Git
- 完整版本历史，支持 merge/rebase 冲突解决
- 需要：远程仓库（GitHub/GitLab/自建）
- 最适合熟悉 Git 的技术用户
- 需要 `.gitignore` 排除大文件和敏感文件

### WebDAV
- 协议层无文件名限制
- 实际行为取决于 WebDAV 客户端（Cyberduck、rclone、系统原生）
- 无内置冲突检测——最后写入覆盖

### rsync / 自建服务器
- 完全控制，同步一切
- 通常是单向的（推送或拉取）
- 无内置冲突处理——依赖时间戳
- 可通过 cron 定时任务实现自动化
