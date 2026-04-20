---
name: multi-device-sync
display_name: WorkBuddy 多设备记忆同步
description: |
  解决 WorkBuddy 用户在多台设备间切换工作时，AI 记忆丢失、上下文断裂的痛点。
  当你在公司电脑和家里电脑之间切换，AI 助手不记得你在另一台设备上做过什么——
  这个技能让 .workbuddy/ 工作记忆在所有设备间自动同步，
  不仅搬数据，还会理解变更并执行行动（新规则内化、待办创建、人设确认等）。
  适用场景：办公室+家里双机工作、多台电脑轮换使用、出差时用笔记本继续工作。
  支持群晖Drive/iCloud/OneDrive/Dropbox/Git等主流同步方式，三种架构自动适配。
  触发词：开工, 收工, 下班, 同步, 多设备, 切入, 切出, switch in, switch out,
  sync devices, multi device, 跨设备, 双机, 多机
---

# WorkBuddy 多设备记忆同步

在多台设备之间保持 WorkBuddy AI 工作记忆（`.workbuddy/`）一致——不只是复制文件，更是让 AI 在每台设备上都"记得你做过什么"，并且接下来要做什么，方便在多个设备之间继续工作。

## 核心概念

你在多台设备上工作时，AI 助手的记忆（`.workbuddy/`）只存在于本地。这个技能解决的就是跨设备同步问题——不只是复制文件，更重要的是**理解变更并执行行动**。

两个操作：
- **切入（Switch In）**："我要在这台设备上开始工作了"——拉取其他设备的变更，分析变化，执行行动
- **切出（Switch Out）**："我在这台设备上做完了"——推送本地状态，让其他设备能获取

## 首次设置

如果 `.workbuddy/` 里没有 `sync-config.yaml`，执行初始化问卷。

### 问卷（分两轮）

**第一轮——基本信息：**

用 `ask_followup_question` 收集：

```json
[
  {
    "id": "device_count",
    "question": "你用几台设备工作？",
    "options": ["2台", "3台", "4台及以上"],
    "multiSelect": false
  },
  {
    "id": "sync_method",
    "question": "你用什么方式在设备间同步文件？",
    "options": [
      "群晖 Synology Drive",
      "iCloud Drive",
      "OneDrive",
      "Dropbox",
      "Google Drive",
      "Syncthing",
      "Git 仓库",
      "WebDAV",
      "rsync / 自建服务器"
    ],
    "multiSelect": false
  }
]
```

第一轮完成后，判断架构（详见 `references/sync-methods.md`）：
- 群晖 / iCloud Drive → **架构 A（中转目录）**
- OneDrive / Dropbox / Google Drive / Syncthing / WebDAV / rsync → **架构 B（直接同步）**
- Git 仓库 → **架构 C（Git）**

**第二轮——设备详情：**

通过对话逐一收集（不用选择题，因为路径需要自由输入）：
1. 设备标识（用户自己起名，如 `办公室`、`家里`、`笔记本`）
2. 操作系统（windows / macos / linux）
3. 工作区完整路径

架构相关：
- **架构 A**：询问中转目录名（默认：`sync-relay`）
- **架构 C**：询问 Git 远程仓库地址

最后问：
- 要自定义触发词吗？（默认：切入 = "开工"，切出 = "收工/下班/结束"）

### 生成配置

写入 `{workspace}/.workbuddy/sync-config.yaml`：

```yaml
version: 1
devices:
  - id: "<用户自定义>"
    os: "<windows|macos|linux>"
    workspace: "<绝对路径>"
  # ... 更多设备
sync_method: "<问卷收集>"
architecture: "<relay|direct|git>"
relay_dir: "<用户自定义或sync-relay>"  # 仅架构A
git_remote: "<地址>"                    # 仅架构C
triggers:
  switch_in: ["开工"]
  switch_out: ["收工", "下班", "结束"]
```

完整问卷规格见 `references/questionnaire.md`。

## 切入同步（Switch In）

**触发**：用户说 `triggers.switch_in` 中的任何词（默认："开工"）。

读取 `sync-config.yaml` 确定当前设备和架构，然后执行：

### Step 0：检查人设文件

读取工作区根目录的 `SOUL.md` 和 `IDENTITY.md`。

与 `.workbuddy/.identity-snapshot`（记录上次状态的 hash 文件）对比：
- 如果 `.identity-snapshot` 不存在 → 首次运行，从当前文件创建，无需对比
- 如果存在 → 计算当前 SOUL.md + IDENTITY.md 的 hash，与存储的比较
  - 一致 → 无人设变更，继续
  - 不一致 → 标记为 🎭 人设变更，留到 Step 3 处理，展示 diff 给用户

**切入完成后**，始终更新 `.identity-snapshot`：
```
soul_hash: <SOUL.md 的 sha256>
identity_hash: <IDENTITY.md 的 sha256>
updated: <ISO-8601 时间戳>
```

### Step 1：拉取其他设备数据

**架构 A（中转目录）**：
详见 `references/architecture-a-relay.md`。
读取 `{relay_dir}/{其他设备ID}/`，这些是其他设备 `.workbuddy/` 的镜像。
- Windows：用 `robocopy` 复制到临时比较目录
- macOS/Linux：用 `rsync` 复制到临时比较目录
- 如果中转目录为空或不存在 → 首次使用，跳到"首次提示"

**架构 B（直接同步）**：
详见 `references/architecture-b-direct.md`。
`.workbuddy/` 已被云服务同步。执行冲突检测：
- 运行 `scripts/detect-conflicts.ps1`（Windows）或 `scripts/detect-conflicts.sh`（macOS/Linux）
- 检查 `.sync-lock` 文件，见下方"锁文件逻辑"

**架构 C（Git）**：
详见 `references/architecture-c-git.md`。
```
cd {workspace}/.workbuddy
git pull --rebase
```
- 如果有合并冲突 → 显示冲突文件，请用户解决
- 如果网络错误（超时/DNS/SSH认证失败）→ 提醒用户："Git 拉取失败，可能是网络问题。可以离线工作，其他设备的变更暂时无法同步。恢复网络后再试 `git pull --rebase`。"
- 如果远程仓库不存在 → 首次设置，见 `references/architecture-c-git.md` "初始化"

### Step 2：对比合并

将拉取的数据与本地 `.workbuddy/` 比较：
- 新文件 → 复制进来
- 已修改文件 → 比较时间戳，保留较新的；如果两边都改了 → 显示 diff，请用户选择
- 已删除文件 → 标记，等用户确认

### Step 3：变更分类

对每个检测到的变更，按文件路径分类：

| 文件模式 | 类型 | 标识 | 处理方式 |
|---------|------|------|---------|
| `SOUL.md`、`IDENTITY.md` | 人设 | 🎭 | 展示 diff，请用户确认 |
| `skills/*/SKILL.md`、`references/` | 规则 | ⚙️ | 合并 + 内化新规则 |
| `automations/`、memory 中出现"待办/提醒/下次" | 任务 | ⏰ | 合并 + 立即创建任务 |
| `scripts/`、`templates/` | 工具 | 🔧 | 合并 + 验证工具可用 |
| `memory/`、其他一切 | 数据 | 📝 | 合并即可，无需额外动作 |

**处理顺序**：🎭 → ⚙️ → ⏰ → 🔧 → 📝（优先级从高到低）

### Step 4：执行行动项

对每个非 📝 变更：
- 🎭 人设：展示 diff 给用户，问"是否接受此变更？"，用户确认后才应用
- ⚙️ 规则：阅读并理解新规则，告知用户："检测到新规则：[摘要]"
- ⏰ 任务：立即创建自动化/提醒/待办
- 🔧 工具：验证脚本/模板存在且可执行

### Step 5：自检

回顾所有处理的变更，输出摘要：

```
=== 切入同步完成 ===
设备：{当前设备ID}
同步来源：{其他设备ID列表}
  📝 数据：N 项已合并
  ⚙️ 规则：N 条新规则已内化
  ⏰ 任务：N 个任务已创建
  🔧 工具：N 个工具已验证
  🎭 人设：N 处变更（已接受/已拒绝）
冲突：无 / N 个已解决
```

然后问："有没有问题？"

### 首次提示

如果没有其他设备的数据：
> "这是你在这台设备上的首次同步。本地 `.workbuddy/` 状态将在你切出时推送到其他设备。现在不需要做什么。"

## 切出同步（Switch Out）

**触发**：用户说 `triggers.switch_out` 中的任何词（默认："收工/下班/结束"）。

### 执行同步

**架构 A（中转目录）**：
将 `.workbuddy/` 镜像到 `{relay_dir}/{当前设备ID}/`：
- Windows：`robocopy "{workspace}\.workbuddy" "{workspace}\{relay_dir}\{device_id}" /MIR /E`
- macOS/Linux：`rsync -av --delete "{workspace}/.workbuddy/" "{workspace}/{relay_dir}/{device_id}/"`

**重要**：中转目录名不要以 `.` 开头，否则过滤点号文件夹的云服务会跳过它。

**架构 B（直接同步）**：
写入 `.sync-lock` 文件（云服务自动处理剩下的）：
```yaml
device: "{当前设备ID}"
timestamp: "{ISO-8601}"
```

**架构 C（Git）**：
```
cd {workspace}/.workbuddy
git add -A
git commit -m "sync-out from {device_id} at {timestamp}"
git push
```
- 如果推送失败（远程有新提交）→ `git pull --rebase`，解决冲突后重新推送
- 如果网络错误 → 提交已保存在本地。提醒用户："推送失败，可能是网络问题。变更已提交到本地，下次有网络时会自动推送，或手动执行 `git push`。"

### 同步后

输出确认信息：
```
=== 切出同步完成 ===
设备：{当前设备ID}
架构：{A/B/C}
状态：✅ 已同步
```

然后问（可选引导，不强制）：
> "要不要设置一个每天提醒切出同步的定时任务？注意：定时任务每次触发都会创建一个新对话，会增加对话列表的条目。"

只有用户说"要"才创建。

## 锁文件逻辑（架构 B）

`.workbuddy/` 中的 `.sync-lock` 文件用于防止直接同步模式下的冲突。

**切入时检查 `.sync-lock`**：
1. 文件不存在 → 正常继续
2. 文件存在，`device` = 当前设备 → 上次未正常切出的残留锁，删除并继续
3. 文件存在，`device` ≠ 当前设备，`timestamp` < 24小时前 → 其他设备刚切出，等云服务同步完成（建议等 30-60 秒），然后继续
4. 文件存在，`device` ≠ 当前设备，`timestamp` > 24小时前 → 过期锁，警告用户（"设备 '{x}' 在超过24小时前切出但锁仍存在，继续执行。"），删除并继续

**切出时**：写入 `.sync-lock`，包含当前设备 ID 和时间戳。

## 冲突检测

完整正则模式见 `references/conflict-patterns.md`。

各服务的冲突文件命名速查：
| 服务 | 命名模式 |
|------|---------|
| Syncthing | `*.sync-conflict-*` |
| OneDrive | `* (1).*`、`* (2).*` |
| Dropbox | `* (conflicted copy *` |
| Google Drive | `* (1).*` |

发现冲突时：
1. 列出所有冲突文件
2. 对每个冲突：显示原文件和冲突副本的 diff
3. 请用户选择保留哪个（或手动合并）
4. 解决后删除冲突副本

## 配置文件恢复

如果 `sync-config.yaml` 解析失败：
1. 检查是否有 sync-config.yaml 的冲突副本 → 使用修改时间最新的
2. 如果没有有效副本 → 重新运行问卷，生成新配置
3. 通知用户："配置文件损坏，已重新生成。"

## 跨平台命令参考

| 操作 | Windows (PowerShell) | macOS/Linux (Bash) |
|------|---------------------|-------------------|
| 目录镜像 | `robocopy "源" "目标" /MIR /E` | `rsync -av --delete "源/" "目标/"` |
| 扫描冲突 | `Get-ChildItem -Recurse -Filter "*.sync-conflict-*"` | `find . -name "*.sync-conflict-*"` |
| 读取 YAML | PowerShell: `ConvertFrom-Yaml` 或手动解析 | `cat` + 解析 |
| Git 操作 | `git pull/push` | `git pull/push` |

切入脚本：`scripts/sync-in.ps1` 或 `scripts/sync-in.sh`
切出脚本：`scripts/sync-out.ps1` 或 `scripts/sync-out.sh`
冲突扫描：`scripts/detect-conflicts.ps1` 或 `scripts/detect-conflicts.sh`
