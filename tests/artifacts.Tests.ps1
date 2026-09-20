$repoRoot = Split-Path -Parent $PSScriptRoot

Describe 'Codex harness artifacts' {
    It 'defines a local marketplace that exposes the harness plugin' {
        $path = Join-Path $repoRoot '.agents/plugins/marketplace.json'
        Test-Path -LiteralPath $path | Should Be $true

        $marketplace = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $marketplace.name | Should Be 'harness-workspace'
        $plugin = @($marketplace.plugins | Where-Object { $_.name -eq 'harness-workspace' })
        $plugin.Count | Should Be 1
        $plugin[0].source.source | Should Be 'local'
        $plugin[0].source.path | Should Be '../..'
        (@($plugin[0].policy.products) -contains 'CODEX') | Should Be $true
    }

    It 'defines a plugin command root' {
        $path = Join-Path $repoRoot '.codex-plugin/plugin.json'
        Test-Path -LiteralPath $path | Should Be $true

        $plugin = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $plugin.name | Should Be 'harness-workspace'
        $plugin.commands | Should Be './commands'
    }

    It 'defines a command that routes to the senior PM coach skill' {
        $path = Join-Path $repoRoot 'commands/senior-pm-coach.md'
        Test-Path -LiteralPath $path | Should Be $true

        $content = Get-Content -LiteralPath $path -Raw
        $content | Should Match '(?s)^---\r?\n.*description:\s*.+?\r?\n---'
        $content | Should Match '\$senior-pm-coach'
    }

    It 'defines a discoverable senior PM coach agent role' {
        $path = Join-Path $repoRoot 'agents/senior-pm-coach/role.toml'
        Test-Path -LiteralPath $path | Should Be $true

        $content = Get-Content -LiteralPath $path -Raw
        $content | Should Match '(?m)^name\s*=\s*"senior-pm-coach"\s*$'
        $content | Should Match '(?m)^description\s*=\s*"[^\"]+"\s*$'
        $content | Should Match '(?s)developer_instructions\s*=\s*"""\s*\S.+?"""'
    }
}
