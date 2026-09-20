$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot 'scripts/link-codex.ps1'
$skillSource = Join-Path $repoRoot 'skills/senior-pm-coach'
$agentSource = Join-Path $repoRoot 'agents'

function Get-NormalizedPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Get-LinkTarget([string]$Path) {
    $item = Get-Item -Force -LiteralPath $Path
    $target = @($item.Target)[0]
    if (-not [System.IO.Path]::IsPathRooted($target)) {
        $target = Join-Path (Split-Path -Parent $Path) $target
    }
    return Get-NormalizedPath $target
}

Describe 'link-codex.ps1 filesystem lifecycle' {
    It 'creates additive skill and agent directory links' {
        $codexHome = Join-Path $TestDrive 'create-home'

        & $scriptPath -CodexHome $codexHome -SkipPluginRegistration | Out-Null

        $skillTarget = Join-Path $codexHome 'skills/senior-pm-coach'
        $agentTarget = Join-Path $codexHome 'agents/harness-workspace'
        (Test-Path -LiteralPath $skillTarget) | Should Be $true
        (Test-Path -LiteralPath $agentTarget) | Should Be $true
        (Get-LinkTarget $skillTarget) | Should Be (Get-NormalizedPath $skillSource)
        (Get-LinkTarget $agentTarget) | Should Be (Get-NormalizedPath $agentSource)
    }

    It 'is idempotent when links already point to this repository' {
        $codexHome = Join-Path $TestDrive 'idempotent-home'
        & $scriptPath -CodexHome $codexHome -SkipPluginRegistration | Out-Null

        $output = (& $scriptPath -CodexHome $codexHome -SkipPluginRegistration | Out-String)

        $output | Should Match 'Skipped:\s+2'
        @(Get-ChildItem -LiteralPath (Join-Path $codexHome 'skills') -Force).Count | Should Be 1
        @(Get-ChildItem -LiteralPath (Join-Path $codexHome 'agents') -Force).Count | Should Be 1
    }

    It 'does not write during dry-run' {
        $codexHome = Join-Path $TestDrive 'dry-run-home'

        $output = (& $scriptPath -CodexHome $codexHome -DryRun -SkipPluginRegistration | Out-String)

        (Test-Path -LiteralPath $codexHome) | Should Be $false
        $output | Should Match '\[DryRun\]'
    }

    It 'preserves a same-name real directory and reports a conflict' {
        $codexHome = Join-Path $TestDrive 'conflict-home'
        $conflict = Join-Path $codexHome 'skills/senior-pm-coach'
        New-Item -ItemType Directory -Path $conflict -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $conflict 'keep.txt') -Value 'keep'

        $output = (& $scriptPath -CodexHome $codexHome -SkipPluginRegistration | Out-String)

        (Get-Content -LiteralPath (Join-Path $conflict 'keep.txt') -Raw).Trim() | Should Be 'keep'
        ((Get-Item -LiteralPath $conflict).Attributes -band [System.IO.FileAttributes]::ReparsePoint) | Should Be 0
        $output | Should Match 'Conflicts:\s+1'
    }

    It 'backs up a real conflict before force-linking' {
        $codexHome = Join-Path $TestDrive 'force-home'
        $conflict = Join-Path $codexHome 'skills/senior-pm-coach'
        New-Item -ItemType Directory -Path $conflict -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $conflict 'keep.txt') -Value 'keep'

        & $scriptPath -CodexHome $codexHome -Force -SkipPluginRegistration | Out-Null

        (Get-LinkTarget $conflict) | Should Be (Get-NormalizedPath $skillSource)
        $backups = @(Get-ChildItem -LiteralPath (Split-Path -Parent $conflict) -Directory | Where-Object { $_.Name -like 'senior-pm-coach.backup-*' })
        $backups.Count | Should Be 1
        (Get-Content -LiteralPath (Join-Path $backups[0].FullName 'keep.txt') -Raw).Trim() | Should Be 'keep'
    }

    It 'unlinks only links that still point to this repository' {
        $codexHome = Join-Path $TestDrive 'unlink-home'
        & $scriptPath -CodexHome $codexHome -SkipPluginRegistration | Out-Null
        $unrelatedSource = Join-Path $TestDrive 'unrelated-agent-source'
        New-Item -ItemType Directory -Path $unrelatedSource -Force | Out-Null
        $agentTarget = Join-Path $codexHome 'agents/harness-workspace'
        Remove-Item -LiteralPath $agentTarget -Force
        New-Item -ItemType Junction -Path $agentTarget -Target $unrelatedSource | Out-Null

        $output = (& $scriptPath -CodexHome $codexHome -Unlink -SkipPluginRegistration | Out-String)

        (Test-Path -LiteralPath (Join-Path $codexHome 'skills/senior-pm-coach')) | Should Be $false
        (Test-Path -LiteralPath $agentTarget) | Should Be $true
        (Get-LinkTarget $agentTarget) | Should Be (Get-NormalizedPath $unrelatedSource)
        $output | Should Match 'Conflicts:\s+1'
    }
}

Describe 'link-codex.ps1 plugin lifecycle' {
    It 'registers the repository command plugin in an isolated Codex home' {
        $codexHome = Join-Path $TestDrive 'plugin-home'
        $previousCodexHome = $env:CODEX_HOME
        try {
            $env:CODEX_HOME = $codexHome

            & $scriptPath -CodexHome $codexHome | Out-Null
            $pluginList = (codex plugin list --json | Out-String) | ConvertFrom-Json

            $plugin = @($pluginList.installed | Where-Object { $_.pluginId -eq 'harness-workspace@harness-workspace' })
            $plugin.Count | Should Be 1
            $plugin[0].enabled | Should Be $true
            $pluginCache = Join-Path $codexHome ("plugins/cache/harness-workspace/harness-workspace/{0}" -f $plugin[0].version)
            $migratedCommand = Join-Path $pluginCache '.codex-plugin/migrated-command-skills/source-command-senior-pm-coach/SKILL.md'
            (Test-Path -LiteralPath $migratedCommand) | Should Be $true
        }
        finally {
            $env:CODEX_HOME = $previousCodexHome
        }
    }

    It 'unregisters only its plugin and marketplace from an isolated Codex home' {
        $codexHome = Join-Path $TestDrive 'plugin-unlink-home'
        $previousCodexHome = $env:CODEX_HOME
        try {
            $env:CODEX_HOME = $codexHome
            & $scriptPath -CodexHome $codexHome | Out-Null
            $installedBeforeUnlink = (codex plugin list --json | Out-String) | ConvertFrom-Json
            @($installedBeforeUnlink.installed | Where-Object { $_.pluginId -eq 'harness-workspace@harness-workspace' }).Count | Should Be 1

            & $scriptPath -CodexHome $codexHome -Unlink | Out-Null

            $pluginList = (codex plugin list --json | Out-String) | ConvertFrom-Json
            @($pluginList.installed | Where-Object { $_.pluginId -eq 'harness-workspace@harness-workspace' }).Count | Should Be 0
            $marketplaceList = (codex plugin marketplace list --json | Out-String) | ConvertFrom-Json
            @($marketplaceList.marketplaces | Where-Object { $_.name -eq 'harness-workspace' }).Count | Should Be 0
        }
        finally {
            $env:CODEX_HOME = $previousCodexHome
        }
    }
}
