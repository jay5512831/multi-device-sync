# 问卷设计

## 概念引导（在问卷之前展示）

在提问之前，先向用户解释核心概念：

> **为什么需要这个技能：**
> 你在多台设备上使用 AI 助手（如 WorkBuddy）时，每台设备都有自己的本地记忆 `.workbuddy/`。也就是说，设备 A 上的 AI 不知道设备 B 上发生了什么。
>
> **这个技能做什么：**
> 它在设备之间同步 AI 的记忆。但不只是复制文件——当你在某台设备上开始工作（"切入"），AI 会读取其他设备上发生的变更，理解这些变更，并采取行动（比如创建任务、学习新规则）。
>
> **怎么用：**
> - 在某台设备上开始工作时，说触发词（默认："开工"）—— AI 会拉取并处理其他设备的变更
> - 做完了，说触发词（默认："收工"）—— AI 会推送你的本地状态，让其他设备能获取
>
> 现在来设置你的设备吧。

## 第一轮：基本设置

使用 `ask_followup_question` 工具：

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

### 架构判定逻辑

第一轮完成后，判断架构：

| 同步方式 | 架构 |
|---------|------|
| 群晖 Synology Drive | relay（中转目录） |
| iCloud Drive | relay（中转目录） |
| OneDrive | direct（直接同步） |
| Dropbox | direct（直接同步） |
| Google Drive | direct（直接同步） |
| Syncthing | direct（直接同步） |
| Git 仓库 | git |
| WebDAV | direct（直接同步） |
| rsync / 自建服务器 | direct（直接同步） |

## 第二轮：设备详情

通过对话逐一收集（不用选择题，因为路径需要自由输入）：

对每台设备（基于第一轮的设备数量）：
1. "给这台设备起个名字吧（建议用地点或用途，如 办公室/家里/笔记本）"
2. "操作系统是什么？"—— windows / macos / linux
3. "工作区的完整路径是什么？"

### 架构相关追加问题

**如果架构 = relay（中转目录）：**
- "中转目录叫什么名字？会创建在你的工作区里。（默认是 sync-relay）"

**如果架构 = git：**
- "Git 仓库的远程地址是什么？（如 git@github.com:user/repo.git）"

### 触发词

- "要自定义触发词吗？"
  - 默认切入：`["开工"]`
  - 默认切出：`["收工", "下班", "结束"]`
  - 如果用户要自定义：收集他们偏好的词

## 生成配置

收集完所有信息后，生成 `sync-config.yaml`：

```yaml
version: 1
devices:
  - id: "{设备1名称}"
    os: "{系统}"
    workspace: "{路径}"
  - id: "{设备2名称}"
    os: "{系统}"
    workspace: "{路径}"
  # 如果有3台以上...
sync_method: "{选择的方式}"
architecture: "{relay|direct|git}"
relay_dir: "{名称}"        # 仅中转目录模式
git_remote: "{地址}"       # 仅 Git 模式
triggers:
  switch_in: ["{触发词}"]
  switch_out: ["{触发词}"]
```

写入 `{当前工作区}/.workbuddy/sync-config.yaml`。

告诉用户：
> "设置完成！配置已保存。下次开始工作时，说'{触发词}'就行，我会帮你同步一切。"

## 重新配置

如果用户说"重新配置同步"或"修改同步设置"：
1. 读取现有配置
2. 展示当前设置
3. 询问要改什么
4. 原地更新配置
