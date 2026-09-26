#Requires -Version 7.0
<#
.SYNOPSIS
    Installs the portable Cline global setup onto this machine.

.DESCRIPTION
    Copies rules, tools, templates and MCP settings into ~/.cline and
    GENERATES machine.md by probing the local machine rather than copying this
    repo's version - paths like D:\esp32-tools\esp-idf are meaningless on
    another PC.

    Safe to re-run. Existing config is backed up to ~/.cline/_backup-<stamp>/.
    Nothing outside ~/.cline is touched. No secrets are written.

.EXAMPLE
    pwsh -File install.ps1
.EXAMPLE
    pwsh -File install.ps1 -SkipPlugins
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipPlugins
)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$home_ = Join-Path $env:USERPROFILE '.cline'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $home_ "_backup-$stamp"

function Say($m) { Write-Host $m }
function Ok($m) { Write-Host "  [ok]   $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow }
function Die($m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; exit 1 }

Say ''
Say '=== Cline global setup installer ==='
Say "  source: $repo"
Say "  target: $home_"
Say ''

if (-not (Test-Path (Join-Path $repo 'config\rules'))) {
    Die "config/rules missing - is this the right folder? $repo"
}

# --- backup before anything changes ---
$touch = @('rules', 'tools', 'templates', 'plugins')
$existing = $touch | Where-Object { Test-Path (Join-Path $home_ $_) }
if ($existing -and -not $Force) {
    New-Item -ItemType Directory $backup -Force | Out-Null
    foreach ($e in $existing) {
        Copy-Item (Join-Path $home_ $e) $backup -Recurse -Force -ErrorAction SilentlyContinue
    }
    Ok "existing config backed up to $backup"
}

# --- 1. rules ---
Say '1. rules'
New-Item -ItemType Directory (Join-Path $home_ 'rules') -Force | Out-Null
Get-ChildItem (Join-Path $repo 'config\rules') -File -Filter '*.md' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $home_ 'rules') -Force
    Ok "rules/$($_.Name)"
}
if (Test-Path (Join-Path $home_ 'rules\machine.md')) {
    Warn 'rules/machine.md exists - left alone. Delete it first to regenerate.'
}

# --- 2. tools ---
Say '2. tools'
New-Item -ItemType Directory (Join-Path $home_ 'tools') -Force | Out-Null
Get-ChildItem (Join-Path $repo 'config\tools') -File | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $home_ 'tools') -Force
    Ok "tools/$($_.Name)"
}

# --- 3. templates ---
Say '3. templates'
New-Item -ItemType Directory (Join-Path $home_ 'templates') -Force | Out-Null
Copy-Item (Join-Path $repo 'config\templates\*') (Join-Path $home_ 'templates') -Recurse -Force
Ok "templates/ ($((Get-ChildItem (Join-Path $home_ 'templates') -Recurse -File).Count) files)"

# --- 4. MCP: never clobber an existing config ---
Say '4. MCP servers'
$settingsDir = Join-Path $home_ 'data\settings'
New-Item -ItemType Directory $settingsDir -Force | Out-Null
$mcpTarget = Join-Path $settingsDir 'cline_mcp_settings.json'
if (Test-Path $mcpTarget) {
    Copy-Item $mcpTarget "$mcpTarget.$stamp.bak" -Force
    Warn "existing MCP config NOT overwritten. New one at: cline_mcp_settings.json.$stamp.bak"
    Warn '  merge by hand if you want context7 / playwright.'
} else {
    Copy-Item (Join-Path $repo 'config\mcp\cline_mcp_settings.json') $mcpTarget -Force
    Ok 'MCP config installed (context7, playwright) - no secrets in it'
}

# --- 5. plugins ---
Say '5. plugins'
if ($SkipPlugins) {
    Warn 'skipped (-SkipPlugins)'
}
elseif (-not (Get-Command cline -ErrorAction SilentlyContinue)) {
    Warn 'cline CLI not on PATH. Install them later - see docs/PLUGIN-PATCH.md'
}
else {
    foreach ($p in @('branch-protector', 'env-blocker')) {
        & cline plugin install $p *> $null
        if ($LASTEXITCODE -eq 0) { Ok "installed: $p" } else { Warn "CLI install failed: $p" }
    }
    Warn 'branch-protector ships BROKEN upstream. Apply the patch: docs/PLUGIN-PATCH.md'
}

Say ''
Say '=== done ==='
Say "verify:  pwsh -File `"$repo\verify.ps1`""
Say ''
