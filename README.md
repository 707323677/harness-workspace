# Harness Workspace

个人 AI Harness 工作区，用于集中维护可复用的 Codex 配置与扩展。

## 目录结构

```text
skills/
  <skill-name>/
    SKILL.md
    agents/openai.yaml
rules/
agents/
```

- `skills/`：可被 Codex 自动发现和调用的 Skill。每个 Skill 使用独立目录，并包含必需的 `SKILL.md`。
- `rules/`：跨任务或跨项目适用的行为规则。
- `agents/`：Agent 定义、角色配置和相关入口文件。

当前包含：

- `skills/senior-pm-coach/`：面向初级产品经理的产品分析与需求澄清教练。

## 使用与维护

1. 在对应顶层目录下新增或修改内容。
2. 新建 Skill 时，确保目录名使用小写连字符，并通过 frontmatter 和可发现性校验。
3. 提交前检查内容中是否包含真实凭据、个人隐私或不应公开的业务资料。
4. 使用清晰、单一目的的提交信息记录变更。

## 分支

- `main`：默认分支，保存稳定内容。
- `release`：用于发布或分发前的整理与验证。

## 公开仓库注意事项

本仓库为公开项目。不要提交 API Key、访问令牌、密码、私有客户资料或其他敏感信息；示例数据应使用脱敏或虚构内容。
