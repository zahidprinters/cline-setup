#Requires -Version 7.0
<#
.SYNOPSIS
    Checks that a Cline global setup is present and working. Read-only.

.DESCRIPTION
    Run this after install.ps1, or any time you suspect something regressed.
    Exit code 0 = all checks passed, 1 = at least one failed.
#>
[CmdletBinding()]
param()

$home_ = Join-Path $env:USERPROFILE '.cline'
$fail = 0
$warn = 0

function Pass($m) { Write-Host "  [PASS] $m" -ForegroundColor Green }
function Bad($m) { Write-Host "  [FAIL] $m" -ForegroundColor Red; $script:fail++ }
function Soft($m) { Write-Host "  [warn] $m" -ForegroundColor Yellow; $script:warn++ }

Write-Host ''
Write-Host '=== Cline setup verification ==='
Write-Host "  target: $home_"
Write-Host ''

# --- rules ---
Write-Host 'rules'
foreach ($r in @('ponytail.md', 'workflow.md', 'isolation.md', 'docs-standard.md', 'machine.md')) {
    $p = Join-Path $home_ "rules\$r"
    if (Test-Path $p) { Pass "rules/$r" }
    elseif ($r -eq 'machine.md') { Soft 'rules/machine.md missing - run gen-machine-md.ps1' }
    else { Bad "rules/$r missing" }
}

# --- tools / templates ---
Write-Host 'tools and templates'
if (Test-Path (Join-Path $home_ 'tools\serial_capture.py')) {
    Pass 'tools/serial_capture.py'
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        $null = & python -c "import serial" 2>&1
        if ($LASTEXITCODE -eq 0) { Pass 'pyserial installed' } else { Soft 'pyserial missing (pip install pyserial) - serial_capture.py needs it' }
    } else { Soft 'python not on PATH' }
} else { Bad 'tools/serial_capture.py missing' }
foreach ($t in @('new-project.ps1', 'gitignore', 'ARCHITECTURE.md')) {
    if (Test-Path (Join-Path $home_ "templates\$t")) { Pass "templates/$t" } else { Bad "templates/$t missing" }
}
if (Test-Path (Join-Path $home_ 'templates\memory-bank\activeContext.md')) { Pass 'templates/memory-bank/' } else { Bad 'templates/memory-bank/ missing' }

# --- MCP ---
Write-Host 'MCP servers'
if (Get-Command cline -ErrorAction SilentlyContinue) {
    $mcp = & cline config mcp 2>&1 | Out-String
    if ($mcp -match 'context7') { Pass 'MCP: context7' } else { Soft 'MCP: context7 not configured' }
    if ($mcp -match 'playwright') { Pass 'MCP: playwright' } else { Soft 'MCP: playwright not configured' }
} else { Soft 'cline CLI not on PATH - cannot list MCP' }

# --- plugin patch integrity ---
Write-Host 'plugins'
$bp = Get-ChildItem (Join-Path $home_ 'plugins\_installed\official') -Directory -Filter 'branch-protector*' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $bp) { Soft 'branch-protector not installed' }
else {
    $idx = Join-Path $bp.FullName 'package\index.ts'
    if (-not (Test-Path $idx)) { Bad 'branch-protector index.ts missing' }
    else {
        $h = (Get-FileHash $idx -Algorithm SHA256).Hash
        $good = '0F71EA0AE0786C691E75C5112E08CF4B2B7DA242D44A256C1AD91D57BA95171A'
        if ($h -eq $good) { Pass 'branch-protector: patched (hash matches known-good)' }
        else {
            Soft "branch-protector hash differs from known-good."
            Soft '  A Cline update may have replaced the patch. Run docs/PLUGIN-PATCH.md'
            Soft '  tests BEFORE assuming it is broken - upstream may have fixed it.'
            Soft "  got: $h"
        }
    }
}
$eb = Get-ChildItem (Join-Path $home_ 'plugins\_installed\official') -Directory -Filter 'env-blocker*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($eb) { Pass 'env-blocker installed' } else { Soft 'env-blocker not installed' }

# --- new-project template sanity ---
Write-Host 'template script'
$np = Join-Path $home_ 'templates\new-project.ps1'
if (Test-Path $np) {
    $err = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($np, [ref]$null, [ref]$err)
    if ($err) { Bad "new-project.ps1 has a parse error: $($err[0].Message)" } else { Pass 'new-project.ps1 parses' }
}

Write-Host ''
if ($fail -gt 0) {
    Write-Host "RESULT: $fail failed, $warn warnings" -ForegroundColor Red
    exit 1
} else {
    Write-Host "RESULT: all checks passed ($warn warnings)" -ForegroundColor Green
    exit 0
}
