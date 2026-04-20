# WorkBuddy 多设备记忆同步

> 🦝 A WorkBuddy Skill — 让 AI 在每台设备上都"记得你做过什么"

## 解决什么问题？

当你在公司电脑和家里电脑之间切换工作时，WorkBuddy 的 AI 记忆（`.workbuddy/`）只存在于本地——AI 助手不记得你在另一台设备上做过什么。

**这个技能解决的就是这个痛点**：在多台设备之间保持 AI 工作记忆一致，不仅搬数据，还会理解变更并执行行动（新规则内化、待办创建、人设确认等），方便在多个设备之间无缝继续工作。

## 适用场景

- 🏢 办公室 + 🏠 家里双机工作
- 💻 多台电脑轮换使用
- ✈️ 出差时用笔记本继续工作

## 支持的同步方式

| 同步服务 | 架构 |
|---------|------|
| 群晖 Drive / iCloud Drive | A. 中转目录模式 |
| OneDrive / Dropbox / Google Drive / Syncthing | B. 直接同步模式 |
| Git 仓库 | C. Git 模式 |

## 核心机制

- **切入（Switch In）**："我要在这台设备上开始工作了"——拉取变更、分析变化、执行行动（6 步流程）
- **切出（Switch Out）**："我在这台设备上做完了"——推送本地状态，让其他设备能获取

同步不只是复制文件，AI 会将每条变更自动分类为 5 种类型并分别处理：

| 类型 | 处理方式 |
|------|---------|
| 📝 纯数据 | 合并即可 |
| ⚙️ 规则变更 | 合并 + AI 内化理解 |
| 🔧 工具变更 | 合并 + 确认可用 |
| ⏰ 任务类 | 合并 + 创建任务/提醒 |
| 🎭 人设变更 | 展示 diff + 用户确认 |

## 安装

将此目录放入 `~/.workbuddy/skills/multi-device-sync/`，WorkBuddy 会自动识别。

首次使用时说"开工"或"同步"即可触发初始化问卷。

## 目录结构

```
multi-device-sync/
├── SKILL.md                    # 主技能文件
├── README.md                   # 本文件
├── references/
│   ├── sync-methods.md         # 同步方式对照表
│   ├── architecture-a-relay.md # 中转目录模式指南
│   ├── architecture-b-direct.md# 直接同步模式指南
│   ├── architecture-c-git.md   # Git 模式指南
│   ├── questionnaire.md        # 问卷设计文档
│   └── conflict-patterns.md    # 冲突文件命名模式
└── scripts/
    ├── sync-in.ps1 / .sh       # 切入同步脚本
    ├── sync-out.ps1 / .sh      # 切出同步脚本
    └── detect-conflicts.ps1/.sh # 冲突检测脚本
```

## 技术要求

- **WorkBuddy** IDE 插件
- 系统内置工具：robocopy（Windows）/ rsync（macOS/Linux）/ git（可选）
- 无第三方依赖

## License

MIT
