---
name: multi-device-sync
display_name: WorkBuddy 多设备记忆同步
description: |
  解决 WorkBuddy 用户在多台设备间切换工作时，AI 记忆丢失、上下文断裂的痛点。
  让 .workbuddy/ 工作记忆在所有设备间自动同步，理解变更并执行行动。
  支持群晖Drive/iCloud/OneDrive/Dropbox/Git等，三种架构自动适配。
  触发词：开工, 收工, 下班, 同步, 多设备, 切入, 切出, switch in, switch out,
  sync devices, multi device, 跨设备, 双机, 多机,
  反馈问题, 报bug, 同步出错, 提交反馈, 同步报错, sync bug, 同步问题
---

# WorkBuddy 多设备记忆同步

> 在多台设备间保持 AI 工作记忆一致——不只复制文件，更理解变更并执行行动。

## 速查卡

| 你要干嘛 | 入口 | 参考文件 |
|---------|------|---------|
| 首次设置 | → 初始化问卷 | `references/questionnaire.md` |
| 在这台设备开始工作 | → 切入同步 | 按架构读取对应 ref |
| 在这台设备结束工作 | → 切出同步 | 按架构读取对应 ref |
| 同步出错了 | → 问题反馈 | `references/bug-report-workflow.md` |

---

## 资源文件索引

| 文件路径 | 内容 | 何时读取 |
|---------|------|---------|
| `references/questionnaire.md` | 两轮问卷完整设计 + 配置生成规格 | 首次设置时 |
| `references/sync-methods.md` | 同步方式 → 架构映射 | 判断架构时 |
| `references/architecture-a-relay.md` | 架构 A（中转目录）完整操作 | 切入/切出架构 A 时 |
| `references/architecture-b-direct.md` | 架构 B（直接同步）完整操作 | 切入/切出架构 B 时 |
| `references/architecture-c-git.md` | 架构 C（Git）完整操作 | 切入/切出架构 C 时 |
| `references/conflict-patterns.md` | 各服务冲突文件命名正则 | 冲突检测时 |
| `references/bug-report-template.md` | Bug 报告模板 | 生成反馈报告时 |
| `references/bug-report-workflow.md` | 反馈收集 6 步流程 | 用户报问题时 |

---

## 核心概念

两个操作：
- **切入（Switch In）**："我要在这台设备上开始工作了"——拉取变更 + 分析 + 执行行动
- **切出（Switch Out）**："我在这台设备上做完了"——推送本地状态

三种架构：
- **A（中转目录）**：群晖 / iCloud Drive
- **B（直接同步）**：OneDrive / Dropbox / Google Drive / Syncthing / WebDAV / rsync
- **C（Git）**：Git 仓库

---

## 首次设置

> **输入**：用户首次使用 → **输出**：`sync-config.yaml` 配置文件
> **模式**：人类在环

如果 `.workbuddy/sync-config.yaml` 不存在，执行两轮问卷。

读取 `references/questionnaire.md` 获取完整问卷设计、分支逻辑和配置文件规格。

---

## 切入同步（Switch In）

> **输入**：用户说"开工" → **输出**：同步摘要报告
> **模式**：人类在环（人设变更和冲突需确认）

1. **检查人设**：对比 SOUL.md / IDENTITY.md 的 hash，变更则展示 diff 等确认
2. **拉取数据**：按架构读取对应 ref（A/B/C），执行拉取操作
3. **对比合并**：新文件复制、修改文件取新、双边修改展示 diff 让用户选
4. **变更分类**：按类型处理（🎭人设 → ⚙️规则 → ⏰任务 → 🔧工具 → 📝数据）
5. **执行行动**：人设等确认、规则内化、任务创建、工具验证
6. **自检输出**：汇总摘要

### 变更分类表

| 文件模式 | 类型 | 处理 |
|---------|------|------|
| `SOUL.md`、`IDENTITY.md` | 🎭 人设 | 展示 diff，等确认 |
| `skills/*/SKILL.md`、`references/` | ⚙️ 规则 | 合并 + 内化 |
| `automations/`、含"待办/提醒" | ⏰ 任务 | 合并 + 创建 |
| `scripts/`、`templates/` | 🔧 工具 | 合并 + 验证 |
| `memory/`、其他 | 📝 数据 | 合并即可 |

---

## 切出同步（Switch Out）

> **输入**：用户说"收工/下班" → **输出**：同步确认
> **模式**：AFK（自动完成）

按架构执行推送操作（读取对应 architecture ref），输出确认信息。

---

## 问题反馈

> **输入**：用户说"同步出错/报bug" → **输出**：结构化 Bug 报告文件
> **模式**：人类在环

读取 `references/bug-report-workflow.md` 获取完整的 6 步反馈收集流程。

---

## 异常处理

| 场景 | 处理 |
|------|------|
| `sync-config.yaml` 不存在 | 进入首次设置问卷 |
| 配置文件解析失败 | 查找冲突副本取最新；无有效副本则重新问卷 |
| 中转目录为空（架构 A） | 首次使用提示，切出时推送 |
| 网络错误（架构 C） | 离线工作，提醒恢复后手动 pull/push |
| 锁文件冲突（架构 B） | 按时间戳判断：同设备残留→删除；他设备<24h→等待；>24h→过期锁删除 |
| 双边同时修改同一文件 | 展示 diff，用户选择保留哪个 |
| 磁盘空间不足 | 提示用户清理后重试 |
| 同步服务未运行 | 检测到中转目录无更新时提醒用户检查同步服务状态 |
| 人设文件被其他设备修改 | 展示 diff，等用户确认后才应用 |
