# Codex Harness Workspace Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an idempotent PowerShell installer that incrementally exposes this repository's Skills, Agent roles, and slash-command workflows to Codex without replacing existing user content.

**Architecture:** Skill directories are linked one by one into `$CODEX_HOME/skills`. Agent roles live in a repository subdirectory linked as `$CODEX_HOME/agents/harness-workspace`, which Codex discovers recursively and which avoids cross-volume file symlink requirements. Commands are registered through a local Codex marketplace/plugin because Codex has no general `$CODEX_HOME/commands` directory.

**Tech Stack:** PowerShell 7/Windows PowerShell 5.1, Pester 3.4-compatible tests, Codex CLI plugin marketplace, JSON/TOML/Markdown configuration.

**Spec:** `docs/superpowers/specs/2026-09-20-codex-harness-integration-design.md`

## Global Constraints

- First version supports Codex only.
- Existing `$CODEX_HOME/skills`, `$CODEX_HOME/agents`, plugins, files, and links must not be replaced.
- A same-name target that is not already the expected link is a conflict and is skipped.
- `-DryRun` performs no filesystem or Codex configuration writes.
- `-Unlink` removes only links that still resolve to this repository and unregisters only this repository's plugin/marketplace.
- Do not modify `config.toml`.
- Rules are out of scope for automatic installation.

---

### Task 1: Define Native Codex Artifacts

**Files:**
- Create: `.agents/plugins/marketplace.json`
- Create: `.codex-plugin/plugin.json`
- Create: `commands/senior-pm-coach.md`
- Create: `agents/senior-pm-coach/role.toml`
- Modify: `docs/superpowers/specs/2026-09-20-codex-harness-integration-design.md`
- Test: `tests/artifacts.Tests.ps1`

**Interfaces:**
- Produces: marketplace `harness-workspace`, plugin `harness-workspace`, migrated command source `senior-pm-coach`, and Agent role name `senior-pm-coach`.

- [ ] **Step 1: Write failing artifact tests**

Test that both JSON files parse, marketplace source is local `../..`, plugin declares `commands`, the command has a non-empty `description` and references `$senior-pm-coach`, and the role TOML includes `name`, `description`, and non-empty `developer_instructions`.

- [ ] **Step 2: Run tests and verify RED**

Run: `Invoke-Pester .\tests\artifacts.Tests.ps1`

Expected: failures because the artifact files do not exist.

- [ ] **Step 3: Add minimal artifacts**

Use a marketplace entry with `products: ["CODEX"]`, a plugin manifest with `commands: "./commands"`, command frontmatter compatible with Codex command migration, and a role that coaches product analysis without fixing a model or reasoning effort.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `Invoke-Pester .\tests\artifacts.Tests.ps1`

Expected: all artifact tests pass.

- [ ] **Step 5: Commit**

```powershell
git add .agents .codex-plugin commands agents tests docs/superpowers/specs
git commit -m "feat: add Codex command and agent artifacts"
```

### Task 2: Implement Incremental Link Lifecycle

**Files:**
- Create: `scripts/link-codex.ps1`
- Create: `tests/link-codex.Tests.ps1`

**Interfaces:**
- Consumes: repository `skills/`, `agents/`, and local plugin manifests.
- Produces: parameters `-DryRun`, `-Force`, `-Unlink`, and optional `-CodexHome`; summary categories `Created`, `Skipped`, `Conflicts`, and `Failed`.

- [ ] **Step 1: Write failing tests for creation and idempotency**

Use Pester's `$TestDrive` to verify the script creates `skills/senior-pm-coach` and `agents/harness-workspace` directory links, then reports them as skipped on a second run. Invoke with `-SkipPluginRegistration` in filesystem-focused tests so no real Codex state changes.

- [ ] **Step 2: Run tests and verify RED**

Run: `Invoke-Pester .\tests\link-codex.Tests.ps1`

Expected: failures because `scripts/link-codex.ps1` does not exist.

- [ ] **Step 3: Implement discovery and safe link creation**

Resolve the repository from `$PSScriptRoot`, resolve Codex home from `-CodexHome`, `CODEX_HOME`, or `$HOME/.codex`, create parent directories only when not in dry-run mode, and create Junctions with `New-Item -ItemType Junction`. Never delete a conflict.

- [ ] **Step 4: Add failing tests for conflicts, dry-run, and unlink**

Cover real-directory conflicts, wrong-link conflicts, no writes under `-DryRun`, and removal only when the link resolves to the expected repository source.

- [ ] **Step 5: Implement conflict and unlink behavior**

`-Force` may rename a real conflict to a timestamped `.backup-*` sibling before linking; it must not silently delete it. `-Unlink` removes only matching reparse points and leaves all other targets untouched.

- [ ] **Step 6: Run tests and verify GREEN**

Run: `Invoke-Pester .\tests\link-codex.Tests.ps1`

Expected: all link lifecycle tests pass.

- [ ] **Step 7: Commit**

```powershell
git add scripts/link-codex.ps1 tests/link-codex.Tests.ps1
git commit -m "feat: add safe Codex link installer"
```

### Task 3: Register Commands and Document Usage

**Files:**
- Modify: `scripts/link-codex.ps1`
- Modify: `tests/link-codex.Tests.ps1`
- Modify: `README.md`

**Interfaces:**
- Consumes: `codex plugin marketplace add`, `codex plugin add`, `codex plugin remove`, and `codex plugin marketplace remove`.
- Produces: installed local command plugin `harness-workspace@harness-workspace`.

- [ ] **Step 1: Write failing plugin command tests**

Run the installer against a temporary `CODEX_HOME`, verify `codex plugin list --json` contains `harness-workspace@harness-workspace`, and verify the installed plugin contains the migrated command skill generated from `commands/senior-pm-coach.md`.

- [ ] **Step 2: Implement plugin registration**

Check `codex` availability, add this repository as a local marketplace only when absent, install the plugin only when absent or stale, and convert non-zero CLI exits into the `Failed` summary. Dry-run prints intended CLI actions without executing them.

- [ ] **Step 3: Implement plugin unregister**

On `-Unlink`, remove only `harness-workspace@harness-workspace` and the marketplace whose configured root resolves to this repository. Leave same-name entries pointing elsewhere as conflicts.

- [ ] **Step 4: Update README**

Document directory structure, default installation, `-DryRun`, `-Force`, `-Unlink`, restart/new-session discovery expectations, `/senior-pm-coach` use, `$senior-pm-coach` fallback, and the no-overwrite conflict policy.

- [ ] **Step 5: Run full verification**

```powershell
Invoke-Pester .\tests
& 'C:\Users\dy707\.codex\skills\.system\skill-creator\scripts\quick_validate.py' .\skills\senior-pm-coach
git diff --check
```

Expected: all tests pass, Skill validation succeeds, and `git diff --check` reports no errors.

- [ ] **Step 6: Commit**

```powershell
git add scripts/link-codex.ps1 tests README.md
git commit -m "docs: explain Codex workspace installation"
```
