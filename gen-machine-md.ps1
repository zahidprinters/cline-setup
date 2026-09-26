#Requires -Version 7.0
<#
.SYNOPSIS
    Generates ~/.cline/rules/machine.md by probing THIS machine.

.DESCRIPTION
    Rules that reference toolchain paths are useless on a machine where those
    paths differ, so this file is generated, never shipped. Run it after moving
    machines, installing ESP-IDF, or changing hardware.
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Continue'
# See install.ps1: $env:USERPROFILE can be stale or redirected. Resolve the
# real profile so we never write a machine.md into a leftover sandbox.
$profileRoot = [Environment]::GetFolderPath('UserProfile')
if (-not $profileRoot -or -not (Test-Path $profileRoot)) { $profileRoot = $env:USERPROFILE }
$out = Join-Path $profileRoot '.cline\rules\machine.md'

if ((Test-Path $out) -and -not $Force) {
    Write-Host "machine.md exists. Re-run with -Force to regenerate." -ForegroundColor Yellow
    exit 0
}
New-Item -ItemType Directory (Split-Path $out) -Force | Out-Null

$L = @()
$L += '# This machine - toolchain inventory'
$L += ''
$L += "# Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') by gen-machine-md.ps1."
$L += 'Regenerate after moving machines or changing toolchains. Never copy this'
$L += 'between machines - it records facts that are only true here.'
$L += ''
$L += '## Runtimes'
$tools = @(
    @{ n = 'Node.js'; c = 'node'; v = @('-v') },
    @{ n = 'Python'; c = 'python'; v = @('--version') },
    @{ n = 'PHP'; c = 'php'; v = @('-r', 'echo PHP_VERSION;') },
    @{ n = 'Composer'; c = 'composer'; v = @('--version') },
    @{ n = 'Git'; c = 'git'; v = @('--version') },
    @{ n = 'Cline CLI'; c = 'cline'; v = @('--version') }
)
foreach ($t in $tools) {
    $c = Get-Command $t.c -ErrorAction SilentlyContinue
    if ($c) {
        $args = $t.v
        $ver = ((& $t.c @args 2>&1 | Select-Object -First 1) -join '').Trim()
        if ($ver -match '^(Error|error)') { $ver = 'installed, version probe failed' }
        $L += ('- **{0}** - {1} - `{2}`' -f $t.n, $ver, $c.Source)
    } else {
        $L += ('- **{0}** - not installed' -f $t.n)
    }
}

$L += ''
$L += '## ESP-IDF'
$idfAll = @()
foreach ($root in @('C:\', 'D:\')) {
    if (Test-Path $root) {
        $idfAll += Get-ChildItem $root -Directory -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'esp-idf*' -and (Test-Path (Join-Path $_.FullName 'tools\idf.py')) }
    }
}
# Prefer the one that the Espressif installer registered, since that is the
# one export.ps1 will actually activate. Fall back to the newest by tag.
$registered = $null
$envFile = Join-Path $env:USERPROFILE '.espressif\idf-env.json'
if (Test-Path $envFile) {
    try {
        $reg = (Get-Content $envFile -Raw | ConvertFrom-Json).idfInstalled.PSObject.Properties
        foreach ($p in $reg) {
            $cand = $p.Value.path
            if ($cand -and (Test-Path (Join-Path $cand 'tools\idf.py'))) { $registered = $cand; break }
        }
    } catch { }
}
if ($registered) {
    $idf = $registered
}
else {
    # No installer record. With more than one checkout this is a genuine
    # ambiguity, and guessing wrong means builds run against the wrong tree.
    # Pick the highest version but say plainly that the choice is unverified.
    $idf = $idfAll | Sort-Object { [version]((git -C $_.FullName describe --tags 2>$null) -replace '^v', '' -replace '-.*$', '') } -Descending | Select-Object -First 1
}

if ($idf) {
    $L += "- path: ``$($idf.FullName)``"
    if (Test-Path (Join-Path $idf.FullName 'export.ps1')) {
        $L += "- activate: ``& '$($idf.FullName)\export.ps1'`` then use ``idf.py``"
    }
    if (Test-Path (Join-Path $idf.FullName '.git')) {
        $tag = (& git -C $idf.FullName describe --tags 2>&1 | Select-Object -First 1)
        if ($tag) { $L += "- version: $tag" }
    }
    if (-not $registered) {
        $L += '- **UNVERIFIED**: no Espressif installer record found, so the newest'
        $L += '  checkout was chosen. Confirm this is the one you want, then fix it'
        $L += '  here by hand. Getting this wrong silently builds against the wrong tree.'
    }
    $L += '- `idf.py mcp-server` does not exist in 5.x releases. Do not promise it.'
    if ($idfAll.Count -gt 1) {
        $L += ''
        $L += '### Other ESP-IDF checkouts found (NOT the active one)'
        foreach ($o in $idfAll) {
            if ($o.FullName -ne $idf.FullName) {
                $t2 = ''
                if (Test-Path (Join-Path $o.FullName '.git')) {
                    $t2 = (& git -C $o.FullName describe --tags 2>&1 | Select-Object -First 1)
                }
                $L += "- ``$($o.FullName)`` $t2"
            }
        }
        $L += '  Several checkouts are fine, but every rule and command must name the'
        $L += '  active one explicitly. Saying "esp-idf" without a path is ambiguous here.'
    }
}
else {
    $L += '- not found on this machine'
}

$L += ''
$L += '## Serial ports'
$ports = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DeviceID
if ($ports) { $L += "- $($ports -join ', ')" } else { $L += '- none detected' }

$L += ''
$L += '## Confirmed at the time of writing'
$L += '- `idf.py monitor` is interactive and will hang a non-interactive shell.'
$L += '- Use `python "$env:USERPROFILE\.cline\tools\serial_capture.py" <PORT> 30` instead.'

$L | Set-Content $out -Encoding utf8
Write-Host "wrote $out ($($L.Count) lines)" -ForegroundColor Green
