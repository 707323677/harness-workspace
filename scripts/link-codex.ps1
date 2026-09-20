[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$Unlink,
    [string]$CodexHome,
    [switch]$SkipPluginRegistration
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Force -and $Unlink) {
    throw '-Force and -Unlink cannot be used together.'
}

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ([string]::IsNullOrWhiteSpace($CodexHome)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $CodexHome = $env:CODEX_HOME
    }
    else {
        $CodexHome = Join-Path $HOME '.codex'
    }
}
$CodexHome = [System.IO.Path]::GetFullPath($CodexHome)

$summary = [ordered]@{
    Created = 0
    Removed = 0
    Skipped = 0
    Conflicts = 0
    Failed = 0
    Planned = 0
}

function Write-Result {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Created', 'Removed', 'Skipped', 'Conflicts', 'Failed', 'Planned')]
        [string]$Kind,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $summary[$Kind]++
    if ($Kind -eq 'Planned') {
        Write-Output "[DryRun] $Message"
    }
    else {
        Write-Output "[$Kind] $Message"
    }
}

function Get-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Get-ReparseTarget {
    param([Parameter(Mandatory = $true)][string]$Path)

    $item = Get-Item -Force -LiteralPath $Path
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $null
    }

    $rawTarget = @($item.Target)[0]
    if ([string]::IsNullOrWhiteSpace($rawTarget)) {
        return $null
    }
    if (-not [System.IO.Path]::IsPathRooted($rawTarget)) {
        $rawTarget = Join-Path (Split-Path -Parent $Path) $rawTarget
    }
    return Get-NormalizedPath $rawTarget
}

function Test-LinkMatches {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedTarget
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }
    $actualTarget = Get-ReparseTarget -Path $Path
    if ($null -eq $actualTarget) {
        return $false
    }
    return $actualTarget -eq (Get-NormalizedPath $ExpectedTarget)
}

function Get-BackupPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stamp = Get-Date -Format 'yyyyMMddHHmmssfff'
    $candidate = "$Path.backup-$stamp"
    $suffix = 0
    while (Test-Path -LiteralPath $candidate) {
        $suffix++
        $candidate = "$Path.backup-$stamp-$suffix"
    }
    return $candidate
}

function Add-DirectoryLink {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (Test-Path -LiteralPath $Target) {
        if (Test-LinkMatches -Path $Target -ExpectedTarget $Source) {
            Write-Result -Kind Skipped -Message "$Label is already linked."
            return
        }

        if (-not $Force) {
            Write-Result -Kind Conflicts -Message "$Label target already exists: $Target"
            return
        }

        $backupPath = Get-BackupPath -Path $Target
        if ($DryRun) {
            Write-Result -Kind Planned -Message "Back up $Target to $backupPath and link it to $Source"
            return
        }

        try {
            Move-Item -LiteralPath $Target -Destination $backupPath
            Write-Output "[Backup] $Target -> $backupPath"
        }
        catch {
            Write-Result -Kind Failed -Message "Could not back up $Label at $Target`: $($_.Exception.Message)"
            return
        }
    }
    elseif ($DryRun) {
        Write-Result -Kind Planned -Message "Link $Target -> $Source"
        return
    }

    try {
        $parent = Split-Path -Parent $Target
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
        Write-Result -Kind Created -Message "$Label linked: $Target -> $Source"
    }
    catch {
        Write-Result -Kind Failed -Message "Could not link $Label`: $($_.Exception.Message)"
    }
}

function Remove-DirectoryLink {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-Path -LiteralPath $Target)) {
        Write-Result -Kind Skipped -Message "$Label is not linked."
        return
    }
    if (-not (Test-LinkMatches -Path $Target -ExpectedTarget $Source)) {
        Write-Result -Kind Conflicts -Message "$Label is not a link to this repository: $Target"
        return
    }
    if ($DryRun) {
        Write-Result -Kind Planned -Message "Remove link $Target"
        return
    }

    try {
        Remove-Item -LiteralPath $Target -Force
        Write-Result -Kind Removed -Message "$Label link removed: $Target"
    }
    catch {
        Write-Result -Kind Failed -Message "Could not unlink $Label`: $($_.Exception.Message)"
    }
}

$linkDefinitions = @()
$skillsRoot = Join-Path $repoRoot 'skills'
if (Test-Path -LiteralPath $skillsRoot) {
    $skillDirectories = Get-ChildItem -LiteralPath $skillsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
        Sort-Object Name
    foreach ($skillDirectory in $skillDirectories) {
        $linkDefinitions += [pscustomobject]@{
            Source = $skillDirectory.FullName
            Target = Join-Path $CodexHome ("skills/{0}" -f $skillDirectory.Name)
            Label = "Skill '$($skillDirectory.Name)'"
        }
    }
}

$agentsRoot = Join-Path $repoRoot 'agents'
$agentRoleFiles = @(Get-ChildItem -LiteralPath $agentsRoot -Filter '*.toml' -File -Recurse -ErrorAction SilentlyContinue)
if ($agentRoleFiles.Count -gt 0) {
    $linkDefinitions += [pscustomobject]@{
        Source = $agentsRoot
        Target = Join-Path $CodexHome 'agents/harness-workspace'
        Label = "Agent collection 'harness-workspace'"
    }
}

foreach ($definition in $linkDefinitions) {
    if ($Unlink) {
        Remove-DirectoryLink -Source $definition.Source -Target $definition.Target -Label $definition.Label
    }
    else {
        Add-DirectoryLink -Source $definition.Source -Target $definition.Target -Label $definition.Label
    }
}

Write-Output ''
Write-Output 'Summary'
foreach ($entry in $summary.GetEnumerator()) {
    Write-Output ("{0}: {1}" -f $entry.Key, $entry.Value)
}

if ($summary.Failed -gt 0) {
    exit 1
}
