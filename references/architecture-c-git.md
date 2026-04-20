# 架构 C：Git 仓库模式

适用于偏好版本控制的技术用户。最可靠的方案，拥有完整历史记录。

## 工作原理

`.workbuddy/` 是一个 Git 仓库。每台设备在本地提交，然后推送/拉取到共享的远程仓库（GitHub、GitLab、自建等）。

## 初始化

### 第一台设备（创建仓库）

```bash
cd {workspace}/.workbuddy
git init
git remote add origin {远程地址}

# 创建 .gitignore
cat > .gitignore << 'EOF'
# 系统文件
.DS_Store
Thumbs.db

# 临时文件
*.tmp
*.swp
*~

# 同步锁（由技能管理，不纳入版本控制）
sync-lock

# 大型二进制文件
*.zip
*.tar.gz
EOF

git add -A
git commit -m "初始化同步"
git push -u origin main
```

### 其他设备（克隆）

```bash
cd {workspace}
git clone {远程地址} .workbuddy
```

如果 `.workbuddy/` 已有本地内容：
```bash
cd {workspace}/.workbuddy
git init
git remote add origin {远程地址}
git fetch
git merge origin/main --allow-unrelated-histories
# 解决冲突
git push -u origin main
```

## 切入

```bash
cd {workspace}/.workbuddy
git pull --rebase
```

**如果出现合并冲突：**
1. 列出冲突文件：`git diff --name-only --diff-filter=U`
2. 对每个文件：
   - 显示冲突内容：`git diff {file}`
   - 请用户选择（保留本地 / 保留远端 / 手动合并）
3. 解决后：
   ```bash
   git add -A
   git rebase --continue
   ```

**如果网络错误**（超时、DNS、SSH 认证）：
- 提醒用户：离线工作没问题，本地记忆正常运作
- 建议稍后重试：`git pull --rebase`
- 其他设备的变更在拉取成功之前不会出现

## 切出

```bash
cd {workspace}/.workbuddy
git add -A
git commit -m "sync-out: {设备ID} at {ISO-8601 时间戳}"
git push
```

如果推送失败（远程有新提交）：
```bash
git pull --rebase
# 解决冲突（如果有）
git push
```

**如果网络错误**：
- 提交已安全保存在本地
- 提醒用户："推送失败，可能是网络问题。变更已提交到本地，下次切出成功时会一并推送，或手动执行 `git push`。"

## 提交信息规范

```
sync-out: {设备ID} at {YYYY-MM-DDTHH:MM:SS}

变更：
- {记忆变更简述}
```

示例：
```
sync-out: 办公室 at 2026-04-20T18:00:00+08:00

变更：
- 更新了 2026-04-20 日志
- 新增每周复盘自动化任务
```

## 安全注意事项

### 私有仓库
- **务必使用私有仓库** —— `.workbuddy/` 可能包含个人笔记、项目详情、API 参考
- GitHub：创建私有仓库
- GitLab：设置可见性为 Private
- 自建：确保需要认证才能访问

### 敏感数据
- 永远不要将 API 密钥或令牌提交到仓库
- 用 `.gitignore` 排除含有秘密信息的文件
- 如果意外提交了敏感信息：使用 `git filter-branch` 或 BFG Repo Cleaner 清理

### 认证方式
- SSH 密钥（推荐）：推送/拉取时无需输入密码
- HTTPS + 凭据助手：`git config credential.helper store`（缓存凭据）
- 个人访问令牌：用于 GitHub/GitLab API 访问

## 相比其他架构的优缺点

- ✅ 完整版本历史——可以回退任何变更
- ✅ 正规的合并冲突解决机制
- ✅ 不依赖任何云同步服务
- ✅ 可以在接受变更前查看 diff
- ⚠️ 需要 Git 知识
- ⚠️ 需要远程仓库
- ⚠️ 复杂合并需要手动解决
