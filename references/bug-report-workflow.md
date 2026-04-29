# 问题反馈收集流程

> 当用户说"反馈问题""报 bug""同步出错了"等词时，按以下 6 步收集诊断信息，生成结构化报告。

---

## Step 1：运行诊断脚本

根据 OS 运行对应脚本（`{skill_dir}` 为本 skill 的安装目录）：
- Windows：`{skill_dir}/scripts/collect-diagnostics.ps1 -WorkspaceRoot "{workspace}"`
- macOS/Linux：`bash {skill_dir}/scripts/collect-diagnostics.sh "{workspace}"`

记录脚本输出，后续填入报告。

## Step 2：读取配置和状态文件

依次读取（不存在则记录"不存在"）：
1. `{workspace}/.workbuddy/sync-config.yaml`
2. `{workspace}/.workbuddy/sync-lock`
3. `{workspace}/.workbuddy/.identity-snapshot`

## Step 3：读取最近同步日志

扫描 `{workspace}/.workbuddy/memory/` 最近 3 天的日志，提取含以下关键词的条目：
- 同步、sync、切入、切出、开工、收工、switch in、switch out

未找到则记录"未找到近 3 天的同步相关日志"。

## Step 4：引导用户描述问题

使用 `ask_followup_question` 一次性收集：

```json
[
  {
    "id": "symptom",
    "question": "遇到了什么问题？（可多选）",
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

然后追问：
1. "能描述一下具体的操作步骤吗？"
2. "有没有看到具体的报错信息？"
3. "还有什么补充信息吗？"

**注意**：如果用户已描述过问题，不重复询问。

## Step 5：生成报告文件

按 `references/bug-report-template.md` 模板填入所有信息。

文件命名：`sync-bug-report-YYYYMMDD-HHMMSS.md`

保存位置：
- Windows：`$env:USERPROFILE\Desktop\`
- macOS：`~/Desktop/`
- Linux：`~/Desktop/`（如存在）或工作区根目录

## Step 6：交付

告知用户报告路径，使用 `deliver_attachments` 交付文件。
