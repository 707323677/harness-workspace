# Codex Harness Workspace Integration Design

## Goal

让 `harness-workspace` 中维护的 Codex Skills、Agent 角色和斜杠命令可以增量加入本机 Codex，同时保留用户已有配置和扩展。

## Scope

第一版只支持 Codex，不处理 Claude Code。集成内容包括：

- `skills/` 下的 Skill 目录；
- `agents/` 下的 Codex Agent 角色文件；
- `commands/` 下的 Codex 原生命令文件，例如 `/senior-pm-coach`。

Rules 暂不作为自动链接目标。行为规则使用 Codex 的 `AGENTS.md`，命令审批规则使用 Codex 的 `.rules` 格式；两者不能因为目录名称相同而盲目互换。

## Chosen Architecture

### 1. Skill 增量链接

`scripts/link-codex.ps1` 从脚本所在位置解析仓库根目录，并将每个有效的 `skills/<name>` 目录逐项链接到 `$CODEX_HOME/skills/<name>`。目录链接优先使用 Windows Junction。

已有 Skill 不会被整个目录替换：

- 目标不存在：创建链接；
- 目标已经指向当前仓库：报告并跳过；
- 目标指向其他位置，或是真实目录/文件：报告冲突并跳过；
- `-Force` 也不直接删除真实内容，必要时先备份再处理。

### 2. Agent 增量链接

`agents/<name>` 下的角色文件逐项链接到 `$CODEX_HOME/agents/<name>`。Agent 只作为可按需调用的角色定义，不在每次命令执行时自动创建子 Agent。只有任务适合隔离、并行或需要专门角色时，Skill 才建议调用它。

### 3. Slash command 注册

Codex 的 `/` 命令由插件的 `commands/` 目录提供，不采用未经证实的 `$CODEX_HOME/commands` 目录约定。仓库增加 `.codex-plugin/plugin.json`，将本仓库作为个人本地插件的命令来源。

命令文件保持轻量，只负责把命令输入路由到已有 Skill。例如：

```text
/senior-pm-coach 帮我梳理这个产品想法
```

命令会要求当前会话使用 `$senior-pm-coach`，并把命令后的文本作为任务上下文；不强制启动 Agent。

安装脚本通过 Codex 原生 marketplace/plugin 命令注册本地插件。插件名称固定为 `harness-workspace`，与已有插件保持独立，避免替换已有 Skill 或 Agent。

### 4. Rules 边界

第一版只保留 `rules/` 作为仓库内容目录，不自动把普通 Markdown 复制或链接到 Codex 的命令规则目录。后续如果加入 `rules/AGENTS.md` 或明确的 `*.rules` 文件，再设计单独映射和校验。

## Script Interface

```powershell
.\scripts\link-codex.ps1
.\scripts\link-codex.ps1 -DryRun
.\scripts\link-codex.ps1 -Force
.\scripts\link-codex.ps1 -Unlink
```

要求：

- 幂等运行；
- 默认禁止覆盖；
- `-DryRun` 不写入本地文件或 Codex 配置；
- `-Unlink` 只移除仍指向当前仓库的链接；
- 忽略 `.gitkeep` 等占位文件；
- 输出创建、跳过、冲突和失败摘要；
- 不修改 `config.toml`，也不替换 `$CODEX_HOME/skills` 或 `$CODEX_HOME/agents` 整个目录；
- 检测 `codex` CLI 不可用、目录链接权限不足和插件注册失败，并给出可执行错误信息。

## Files

- Create: `.codex-plugin/plugin.json` - 本地插件清单，仅声明个人工作区命令入口。
- Create: `commands/senior-pm-coach.md` - `/senior-pm-coach` 命令路由。
- Create: `agents/senior-pm-coach.toml` - 可按需调用的产品教练 Agent 角色。
- Create: `scripts/link-codex.ps1` - Skill/Agent 增量链接和命令插件注册。
- Modify: `README.md` - 安装、验证、冲突处理、卸载和命令用法。

## Verification

- PowerShell 解析检查脚本无语法错误；
- `-DryRun` 在临时 Codex 目录下能发现待创建项且不写入；
- 正常运行后重复运行只产生跳过，不覆盖已有目标；
- 冲突目标被保留并报告；
- `-Unlink` 只移除当前仓库创建的链接；
- Skill frontmatter、插件 manifest、命令文件和 Agent 角色文件通过结构校验；
- Codex marketplace/plugin CLI 能识别本地插件清单。
