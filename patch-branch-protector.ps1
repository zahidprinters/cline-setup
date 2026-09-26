#Requires -Version 7.0
<#
.SYNOPSIS
    Applies the branch-protector fix and verifies it by hash.

.DESCRIPTION
    The official branch-protector plugin has two defects that make it a silent
    no-op against the real runtime:
      1. it reads toolCall.input.command (string) but the runtime sends
         toolCall.input.commands (string[]), so "if (!command) return" exits;
      2. its regex is anchored with ^, so "cd x && git push" never matches.
    Plus a third found only in production: context can be undefined, and
    context.cwd threw, aborting the task.

    This copies the fixed index.ts over the installed one. The installed
    directory name is hash-suffixed and differs per machine, so it is
    discovered rather than hard-coded.

.PARAMETER Revert
    Restore the ORIGINAL broken index.ts. Only useful to prove the bug exists.

.EXAMPLE
    pwsh -File patch-branch-protector.ps1
.EXAMPLE
    pwsh -File patch-branch-protector.ps1 -Revert
#>
[CmdletBinding()]
param([switch]$Revert)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$home_ = Join-Path $env:USERPROFILE '.cline'
$KNOWN_GOOD = '0F71EA0AE0786C691E75C5112E08CF4B2B7DA242D44A256C1AD91D57BA95171A'

$dir = Get-ChildItem (Join-Path $home_ 'plugins\_installed\official') -Directory -Filter 'branch-protector*' -ErrorAction SilentlyContinue |
    Select-Object -First 1
if (-not $dir) {
    Write-Host 'branch-protector is not installed. Run: cline plugin install branch-protector' -ForegroundColor Yellow
    exit 1
}
$target = Join-Path $dir.FullName 'package\index.ts'
$src = Join-Path $repo ($(if ($Revert) { 'config\plugins\branch-protector\ORIGINAL-index.ts' } else { 'config\plugins\branch-protector\index.ts' }))

if (-not (Test-Path $target)) { Write-Host "no index.ts at $target" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $src)) { Write-Host "patch source missing: $src" -ForegroundColor Red; exit 1 }

if (-not $Revert) {
    Copy-Item $target "$target.pre-patch.bak" -Force -ErrorAction SilentlyContinue
    Write-Host "  backup: $target.pre-patch.bak" -ForegroundColor DarkGray
}

Copy-Item $src $target -Force
$h = (Get-FileHash $target -Algorithm SHA256).Hash
Write-Host "  wrote $target" -ForegroundColor Green
Write-Host "  sha256 $h" -ForegroundColor DarkGray

if ($Revert) {
    Write-Host ''
    Write-Host 'Reverted to the original broken plugin. Do not leave it like this.' -ForegroundColor Yellow
} elseif ($h -eq $KNOWN_GOOD) {
    Write-Host ''
    Write-Host 'HASH MATCHES known-good patched version.' -ForegroundColor Green
    Write-Host 'RESTART Cline (VS Code: Developer > Reload Window) to load it.'
    Write-Host 'Then prove it: see docs/PLUGIN-PATCH.md "live tests".'
} else {
    Write-Host ''
    Write-Host 'HASH DOES NOT MATCH. Expected:' -ForegroundColor Red
    Write-Host "  $KNOWN_GOOD" -ForegroundColor Red
}
Write-Host ''
