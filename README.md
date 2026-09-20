# Harness Workspace

个人 AI Harness 工作区，用于集中维护可复用的 Codex 配置与扩展。

## 目录结构

```text
skills/
  <skill-name>/
    SKILL.md
    agents/openai.yaml
agents/
  <agent-name>/
    role.toml
commands/
  <command-name>.md
rules/
scripts/
  link-codex.ps1
```

- `skills/`：可被 Codex 自动发现和调用的 Skill。每个 Skill 使用独立目录，并包含必需的 `SKILL.md`。
- `agents/`：可由 Codex 按需创建的 Agent 角色；角色目录中包含 `role.toml`。
- `commands/`：Codex 插件命令入口，可通过 `/` 菜单调用对应工作流。
- `rules/`：跨任务或跨项目适用的行为规则；当前安装脚本不会自动映射该目录。
- `scripts/`：本地安装和维护脚本。

当前包含：

- `skills/senior-pm-coach/`：面向初级产品经理的产品分析与需求澄清教练。
- `agents/senior-pm-coach/`：用于独立调研、竞品分析或方案审视的按需 Agent 角色。
- `commands/senior-pm-coach.md`：`/senior-pm-coach` 命令入口。

## 安装到 Codex

要求 Windows PowerShell 5.1 或 PowerShell 7，并确保 `codex` 命令可用。

先预览将执行的操作：

```powershell
.\scripts\link-codex.ps1 -DryRun
```

确认无冲突后安装：

```powershell
.\scripts\link-codex.ps1
```

脚本会：

1. 将每个 Skill 逐项链接到 `$CODEX_HOME/skills/<skill-name>`；
2. 将本仓库的 Agent 集合链接到 `$CODEX_HOME/agents/harness-workspace`；
3. 通过 Codex CLI 注册本地 marketplace 和 `harness-workspace` 命令插件。

它不会替换整个 `skills/` 或 `agents/` 目录。同名目标如果不是本仓库创建的链接，默认报告冲突并保留原内容。

已有冲突内容需要迁移时，可以显式使用：

```powershell
.\scripts\link-codex.ps1 -Force
```

`-Force` 会先把冲突项重命名为同目录下的 `.backup-<timestamp>`，再创建链接；它也会重新安装本仓库的命令插件。不会直接删除冲突内容。

卸载本仓库的链接和命令插件：

```powershell
.\scripts\link-codex.ps1 -Unlink
```

卸载只移除仍指向当前仓库的链接，以及来源仍是当前仓库的 `harness-workspace` plugin/marketplace。其他文件、链接和插件保持不变。

如需使用其他 Codex Home，可传入：

```powershell
.\scripts\link-codex.ps1 -CodexHome 'D:\path\to\.codex'
```

## 调用

安装后新建 Codex 会话；如果 `/` 菜单尚未刷新，请重启 Codex。

```text
/senior-pm-coach 帮我梳理这个产品想法
```

也可以直接调用 Skill：

```text
$senior-pm-coach 帮我梳理这个产品想法
```

命令默认在当前会话中执行 Skill。只有出现适合隔离或并行处理的独立调研、竞品分析或专项验证任务时，才按需调用 `senior-pm-coach` Agent。

## 使用与维护

1. 在对应顶层目录下新增或修改内容。
2. 新建 Skill 时，确保目录名使用小写连字符，并通过 frontmatter 和可发现性校验。
3. 新增命令时提供非空 `description` frontmatter，并让命令只负责路由，具体能力保留在 Skill 中。
4. 新增 Agent 时使用独立目录和 `role.toml`，至少提供 `name`、`description` 和 `developer_instructions`。
5. 修改命令后运行 `link-codex.ps1 -Force` 刷新插件缓存。
6. 提交前检查内容中是否包含真实凭据、个人隐私或不应公开的业务资料。
7. 使用清晰、单一目的的提交信息记录变更。

## 分支

- `main`：默认分支，保存稳定内容。
- `release`：用于发布或分发前的整理与验证。

## 公开仓库注意事项

本仓库为公开项目。不要提交 API Key、访问令牌、密码、私有客户资料或其他敏感信息；示例数据应使用脱敏或虚构内容。
