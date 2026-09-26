param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Root = (Get-Location).Path,
    [string]$Description = '',
    [string]$Author = '',
    [ValidateSet('MIT', 'Apache-2.0', 'GPL-3.0', 'Unlicense', 'Proprietary')]
    [string]$License = 'MIT',
    [switch]$Init
)

$ErrorActionPreference = 'Stop'
$project = Join-Path $Root $Name

if (Test-Path $project) {
    Write-Error "Already exists: $project  (pick another name; nothing was changed)"
    exit 1
}

# Project identity. Falls back to the configured git identity so a new project
# is never left with an unowned author.
if (-not $Author) {
    $Author = (git config --global user.name 2>$null)
    if (-not $Author) { $Author = 'TODO: set your name' }
}
$Year = (Get-Date).Year

# SPDX id per license, so GitHub labels the repo correctly.
$spdx = @{ 'MIT' = 'MIT'; 'Apache-2.0' = 'Apache-2.0'; 'GPL-3.0' = 'GPL-3.0-only'; 'Unlicense' = 'Unlicense'; 'Proprietary' = 'LicenseRef-Proprietary' }
$spdxId = $spdx[$License]

# Standard layout. temp/ and logs/ are created empty and gitignored: they hold
# per-project scratch and run output so nothing bleeds between projects.
# Standard layout. temp/ and logs/ are created empty and gitignored: they hold
# per-project scratch and run output so nothing bleeds between projects.
# memory-bank/ is filled by the template copy below, not created here.
foreach ($dir in @('docs', 'src', 'tests', 'temp', 'logs')) {
    New-Item -ItemType Directory -Path (Join-Path $project $dir) -Force | Out-Null
}

# Templates travel with the script so a new project is never without a map or
# a memory bank. Both are copied, not referenced: a project must work when
# this templates folder moves or is deleted.
foreach ($pair in @(
    @('ARCHITECTURE.md', 'docs\ARCHITECTURE.md'),
    @('memory-bank', 'memory-bank')
)) {
    $src = Join-Path $PSScriptRoot $pair[0]
    $dst = Join-Path $project $pair[1]
    if (Test-Path $src) {
        # -Force merges into an existing dir. Without it a pre-existing empty
        # memory-bank/ would nest a second copy inside itself.
        Copy-Item $src $dst -Recurse -Force
    }
    else {
        Write-Warning "Template not found: $src - $dst not created."
    }
}

# The shared stack gitignore travels with the script: one source of truth for
# all projects, instead of a thinner copy drifting inside this script.
$ignoreTemplate = Join-Path $PSScriptRoot 'gitignore'
if (Test-Path $ignoreTemplate) {
    Copy-Item $ignoreTemplate (Join-Path $project '.gitignore')
}
else {
    # Fallback so a project is never created without ignore rules.
    Write-Warning "gitignore template not found - writing a minimal fallback."
    "build/`n*.o`n*.elf`n*.bin`nnode_modules/`nvendor/`n.venv/`n__pycache__/`n.env`ntemp/`nlogs/`n.vscode/" |
        Set-Content -Path (Join-Path $project '.gitignore') -Encoding utf8
}

# Built as a variable first: a here-string piped straight into Set-Content
# does not expand $spdxId correctly in the closing line.
$licenseText = @"
# LICENSE - $License (SPDX: $spdxId)
# Full text: https://spdx.org/licenses/$spdxId.html
#
# Proprietary? Replace this file with your commercial terms. This notice only
# records the intended license; it is not a substitute for the full text.
Copyright (c) $Year $Author

Licensed under the $License license.

SPDX-License-Identifier: $spdxId
"@
$licenseText | Set-Content -Path (Join-Path $project 'LICENSE') -Encoding utf8

# Machine-readable identity, so tooling and the agent never have to parse the
# README to learn who owns this or what it is.
@{
    name        = $Name
    description = if ($Description) { $Description } else { 'TODO: describe this project' }
    author      = $Author
    license     = $spdxId
    created     = (Get-Date -Format 'yyyy-MM-dd')
} | ConvertTo-Json | Set-Content -Path (Join-Path $project 'project.json') -Encoding utf8

@"
# $Name

$Description

| | |
|---|---|
| **Author** | $Author |
| **License** | $License (SPDX: $spdxId) |
| **Status** | PLAN / DEV / TEST / PRODUCTION |

## Quick start
    <exact commands to install deps, run, and test>

## Layout
- \`src/\` - code
- \`tests/\` - tests
- \`docs/ARCHITECTURE.md\` - **start here**, the project map
- \`temp/\`, \`logs/\` - local scratch, gitignored

## Documentation
- [Architecture map](docs/ARCHITECTURE.md)
- [Changelog](CHANGELOG.md)
"@ | Set-Content -Path (Join-Path $project 'README.md') -Encoding utf8

@'
# Changelog

Newest first. Append only - never rewrite history.

## Unreleased

## YYYY-MM-DD - Title
- **What:** changed
- **Why:** reason
- **Tested:** exact commands + result
- **Not tested:** what remains unverified
'@ | Set-Content -Path (Join-Path $project 'CHANGELOG.md') -Encoding utf8

Write-Output "Created: $project"

if ($Init) {
    Push-Location $project
    try {
        git init -q
        git add -A
        git commit -q -m "chore: initial project scaffold"
        Write-Output "Git initialised with first commit."
    }
    catch {
        Write-Warning "Git init/commit failed: $($_.Exception.Message)"
    }
    finally {
        Pop-Location
    }
}

Write-Output ''
Write-Output 'Next: open docs/ARCHITECTURE.md and fill in Purpose, Stack and Layout.'
