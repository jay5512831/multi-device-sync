# Bug Report Template

> AI 按此模板收集诊断信息并生成报告文件。用户不需要手动填写——AI 自动采集大部分字段，仅引导用户描述问题部分。

## 报告文件命名

`sync-bug-report-YYYYMMDD-HHMMSS.md`

示例：`sync-bug-report-20260421-143052.md`

## 模板结构

以下是生成的报告文件的完整结构。`{...}` 标记的字段由 AI 自动填充。

---

```markdown
# 同步问题报告

> 生成时间：{ISO-8601 时间戳}
> 设备标识：{sync-config.yaml 中当前设备的 id}
> 操作系统：{OS 名称 + 版本，如 Windows 11 23H2}

---

## 1. 问题描述

**现象**：{用户描述：出了什么问题}

**复现步骤**：
{用户描述：怎么操作会触发这个问题}
1. ...
2. ...

**期望行为**：{用户描述：你觉得正确的表现是什么}

**实际行为**：{用户描述：实际发生了什么}

**严重程度**：{AI 判断：阻断使用 / 功能异常但可绕过 / 轻微不便}

---

## 2. 环境信息

| 项目 | 值 |
|------|-----|
| OS | {os_name} {os_version} |
| Shell | {PowerShell x.x / Bash x.x / Zsh x.x} |
| Skill 版本 | SKILL.md 修改日期: {YYYY-MM-DD}; 文件大小: {N} bytes |
| WorkBuddy 版本 | {如果能获取} |

---

## 3. 同步配置

> 以下为 sync-config.yaml 的完整内容

```yaml
{sync-config.yaml 完整内容，原样粘贴}
```

**关键配置解读**：
- 架构类型：{relay / direct / git}
- 同步方式：{群晖 Drive / iCloud / OneDrive / ...}
- 设备数量：{N} 台

---

## 4. 同步状态

### sync-lock
{文件内容，或"文件不存在"}

### .identity-snapshot
{文件内容，或"文件不存在"}

### 中转目录 / 同步目录结构
{目录 tree 输出，只列到 2 层深度}

---

## 5. 最近同步日志

> 从 memory 文件中提取最近 3 天内含有"同步""sync""切入""切出""开工""收工"关键词的条目

{相关日志条目，保留原始时间戳}

如果没有找到相关日志，写："未找到近 3 天的同步相关日志"

---

## 6. 错误信息

{控制台报错输出、脚本返回的错误信息，或用户描述的错误提示}

如果没有明确的错误信息，写："用户未提供具体错误信息"

---

## 7. 补充信息

{用户提供的任何额外上下文，如"刚换了同步方式""昨天还好用的"等}

如果没有，写："无"
```

---

## 字段采集方式汇总

| 字段 | 采集方式 | 备注 |
|------|---------|------|
| 生成时间 | AI 自动 | 当前时间 |
| 设备标识 | AI 读 sync-config.yaml | 根据当前 workspace 路径匹配 |
| OS + 版本 | 运行 collect-diagnostics 脚本 | — |
| Shell 版本 | 运行 collect-diagnostics 脚本 | — |
| Skill 版本 | 运行 collect-diagnostics 脚本 | SKILL.md 的修改日期和大小 |
| sync-config.yaml | AI 读文件 | 完整内容 |
| 架构/同步方式 | 从 config 解析 | — |
| sync-lock | AI 读文件 | 可能不存在 |
| .identity-snapshot | AI 读文件 | 可能不存在 |
| 目录结构 | 运行 collect-diagnostics 脚本 | 2 层深度 |
| 同步日志 | AI 读 memory 文件 | 关键词过滤 |
| 问题描述 | 对话引导 | 用 ask_followup_question |
| 错误信息 | 对话引导 + 脚本输出 | — |
| 补充信息 | 对话引导 | 可选 |

## AI 引导对话流程

收集用户描述时，使用 `ask_followup_question` 一次性收集：

```json
[
  {
    "id": "symptom",
    "question": "遇到了什么问题？（简要描述现象）",
    "options": [
      "切入同步失败/报错",
      "切出同步失败/报错",
      "同步后数据丢失或不一致",
      "配置文件损坏或无法解析",
      "冲突文件未正确处理",
      "其他问题（请在下一步补充）"
    ],
    "multiSelect": true
  },
  {
    "id": "severity",
    "question": "问题严重程度？",
    "options": [
      "完全无法同步（阻断使用）",
      "部分功能异常但可绕过",
      "轻微不便"
    ],
    "multiSelect": false
  }
]
```

然后追问细节（自由文本）：
1. "能描述一下具体的操作步骤吗？（做了什么操作后出现问题）"
2. "有没有看到具体的报错信息？（如果有，请贴出来）"
3. "还有什么补充信息吗？（比如最近改过配置、换过同步方式等）"

## 报告保存位置

默认保存到用户桌面：
- Windows: `$env:USERPROFILE\Desktop\sync-bug-report-YYYYMMDD-HHMMSS.md`
- macOS: `~/Desktop/sync-bug-report-YYYYMMDD-HHMMSS.md`
- Linux: `~/Desktop/sync-bug-report-YYYYMMDD-HHMMSS.md`（如果存在）或当前工作区根目录

保存后提示用户："报告已保存到 {路径}，请将此文件发给 MC 即可。"
