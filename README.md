# Cline Setup

A portable, reproducible global Cline development environment for VS Code, the
Cline CLI, and the Cline SDK.

This repository provides a machine-independent way to configure Cline for
embedded development, ESP32/ESP-IDF, Arduino, C/C++, Python, PHP, JavaScript,
HTML/CSS, Git, testing, documentation, and multi-project workflows.

All three Cline surfaces read `~/.cline/`, so there is no separate
configuration per environment. Installing once covers all of them.

## What it solves

Cline's global configuration normally lives inside the user's home directory
and can contain machine-specific rules, paths, tools, skills, plugins,
templates, and MCP configuration.

Copying that configuration directly to another computer causes problems,
because paths, installed toolchains, project locations, and software versions
differ.

`cline-setup` separates **portable configuration** from **machine-specific
configuration**. The repository holds the reusable setup; `gen-machine-md.ps1`
detects the current computer and generates the appropriate `machine.md`.

Everything here was **verified by running it**, not merely by configuring it.
Where a claim is unverified, this README says so.

## Install on a new machine

```powershell
git clone https://github.com/zahidprinters/cline-setup.git
cd cline-setup
pwsh -File install.ps1
pwsh -File gen-machine-md.ps1      # probes THIS machine, writes rules/machine.md
pwsh -File verify.ps1              # confirms the install
```

Then, once:

```powershell
cline plugin install branch-protector
cline plugin install env-blocker
pwsh -File patch-branch-protector.ps1    # the shipped fix - see docs/PLUGIN-PATCH.md
```

**Restart Cline afterwards.** VS Code: `Developer > Reload Window`.

## Main features

### Portable global rules

- Development workflow and task sizing
- Execution phases: plan, build, self-test, hand off, production
- Testing and verification discipline
- Serial debugging
- Documentation standards
- Git safety
- Project isolation
- Machine and toolchain awareness
- Senior-developer workflow preferences

Machine-specific paths are never hard-coded into the portable rules.

### Automatic machine detection

`gen-machine-md.ps1` probes the local machine and generates:

```text
~/.cline/rules/machine.md
```

It detects the toolchains present: ESP-IDF, Git, PowerShell, PHP, Python,
Node.js, Cline itself, and serial ports.

**ESP-IDF detection is deliberately conservative.** When multiple ESP-IDF
installations exist, the script prefers the installer-registered one from
`.espressif/idf-env.json` rather than arbitrarily selecting one. If the active
installation cannot be verified it reports the file as **UNVERIFIED** instead of
silently generating a wrong configuration, and lists every other checkout found.

### ESP32 / ESP-IDF support

- C/C++ and ESP-IDF
- Arduino
- Serial monitoring and flashing
- Build, test and debug cycles
- Wi-Fi and network debugging
- Component dependencies
- Embedded project documentation

`idf.py monitor` is interactive and will hang a non-interactive shell, so
`tools/serial_capture.py` is provided as a non-interactive alternative.

### Branch protection

The repository includes a **patched** `branch-protector` plugin. The official
plugin is a silent no-op against the real runtime: it reads
`toolCall.input.command` while the runtime sends `toolCall.input.commands[]`,
so its hook never fires. Its regex is also anchored with `^`, so
`cd x && git push` never matches.

The protection prevents accidental pushes to protected branches:

```text
master
main
release/*
```

The patch is verified using **SHA-256**, not file size. The original ships
alongside it, so the change can be reverted with `-Revert`.

If a future Cline or plugin update changes the installed hash, run the
documented live tests **before** applying the patch again - a changed hash may
represent a legitimate upstream fix.

### Verification

`verify.ps1` checks the installation read-only and returns a non-zero exit code
on failure. It does not modify unrelated files.

## Repository structure

```text
cline-setup/
├── install.ps1                    copy portable config into ~/.cline
├── gen-machine-md.ps1             probe this machine -> rules/machine.md
├── verify.ps1                     read-only health check
├── patch-branch-protector.ps1     apply/revert the plugin fix, hash-verified
├── project.json
├── config/                        what gets installed
│   ├── rules/                     4 portable rules (machine.md NOT here)
│   ├── tools/                     serial_capture.py
│   ├── templates/                 new-project.ps1, gitignore, map, memory bank
│   ├── plugins/                   branch-protector (patched + original), env-blocker
│   └── mcp/                       cline_mcp_settings.json (no secrets)
└── docs/
    ├── PLUGIN-PATCH.md            the defect, the fix, the six live tests
    └── AUDIT-2026-09-26.txt       audit record behind the current config
```

Two things are deliberately **absent**:

- `machine.md` is generated per machine, never committed. Committing it would
  ship rules that confidently state the wrong paths.
- `skills/` is not vendored. Skills are installed per machine with
  `cline skill install`; vendoring a large third-party skill whose provenance
  cannot be verified is not worth it.

## Creating a new project

```powershell
pwsh -File "$env:USERPROFILE\.cline\templates\new-project.ps1" `
    -Name my-sensor -Root D:\projects -Description "what it does" -Init
```

Creates `docs/ARCHITECTURE.md`, `memory-bank/`, `src/`, `tests/`, `temp/`,
`logs/`, a sectioned `.gitignore`, a `LICENSE`, `project.json`, and a first git
commit.

## Design principles

### Portable by default

The repository never assumes another computer has the same drive letters,
ESP-IDF installation, Python, PHP, Node, project directories, git config, or
user name.

### Detect instead of guess

If the setup cannot confidently identify a toolchain, it reports the
uncertainty rather than silently selecting a potentially wrong installation.

### Verify before modifying

Scripts validate their inputs and their results. A green unit test is not
proof: the `branch-protector` fix passed 18/18 in a harness and still crashed
in production on `context.cwd`. Only a live test counts.

### Keep secrets out

Credentials, tokens, API keys, SSH private keys, auth headers and `.env` files
do not belong in this repository. The MCP config ships without tokens; if you
add an authenticated server, keep the value in an environment variable.

### Preserve rollback capability

Plugin changes have a documented rollback path, and the original file ships
with the patch.

### Keep global context useful

Global rules hold cross-project behaviour useful everywhere. Project-specific
knowledge belongs in that project rather than being loaded globally.

## Measured context cost

```text
Cline floor (system prompt + tools + MCPs)   6,990 tokens
Global rules                                4,471 tokens
                                            ---------
Request before any project file is read     11,461 tokens
```

Three runs per arm, zero variance. The floor is the reason to keep the MCP list
short: every server added raises it permanently, on every request.

## Clean-room verification

Tested in an isolated environment, not only against the existing live
installation. Verified:

- Fresh install into an empty home directory
- All four scripts parse
- Machine detection, including PHP version and multi-checkout ESP-IDF
- Verification passes on a valid install and warns on a missing plugin
- Secret scan of every committed file
- MCP config contains no auth header
- The live `~/.cline` configuration was untouched throughout

## Current release state

```text
4b48dca  chore: portable Cline global setup
```

The working tree is clean.

## Security note

Do not commit GitHub tokens, API keys, SSH private keys, passwords,
authentication headers, `.env` files, or personal credentials.

`docs/AUDIT-2026-09-26.txt` records real toolchain paths from the authoring
machine. That is intentional and useful, but review any audit or debug document
before publishing a repository publicly.

## Troubleshooting

**`verify.ps1` reports a branch-protector hash mismatch.** A Cline update
replaced the patch. Do not assume it regressed - read `docs/PLUGIN-PATCH.md` and
run the six live tests first.

**Rules do not seem to load.** Confirm `~/.cline/rules/` exists and restart
Cline. Global rules are shared with the VS Code extension, so there is no
separate extension-side setup.

**`idf.py` behaves oddly.** You may have more than one ESP-IDF checkout. Check
the "Other ESP-IDF checkouts" section of `rules/machine.md` and always name the
active path explicitly.

## Intended users

Developers working across multiple projects involving ESP32, ESP-IDF, Arduino,
embedded C/C++, Python, PHP, JavaScript, HTML/CSS, Git/GitHub, VS Code, the
Cline CLI, or the Cline SDK.

The goal is not to publish one person's machine configuration. The goal is a
**repeatable development environment that configures itself for the machine on
which it is installed**.

## Live sync status

**`D:\cline-setup` is the source of truth. `C:\Users\PC\.cline` is a copy.**

Edit files in `config/`, commit, then reinstall. Never hand-edit `~/.cline` - a
change made there is lost on the next sync and invisible to anyone else using
this repo.

### Workflow

```powershell
# 1. edit D:\cline-setup\config\...
# 2. commit
cd D:\cline-setup
git add -A
git commit -m "..."

# 3. push the live copy back in sync
pwsh -File install.ps1

# 4. prove it
pwsh -File verify.ps1
```

`install.ps1` is idempotent and backs up to `~/.cline/_backup-<stamp>/` first.
`machine.md` is regenerated separately and is never committed:

```powershell
pwsh -File gen-machine-md.ps1 -Force
```

### What is deliberately NOT in this repo

| Item | Why it stays out |
|---|---|
| `machine.md` | records paths true only on one machine; committing it ships rules that lie |
| `skills/` | installed per machine; a vendored third-party skill has unverified provenance |
| MCP credentials | tokens go in an environment variable, never a file |
| `~/.cline/data/` | sessions, databases, logs - runtime state, not configuration |

### Project independence

No project in `D:\` references this repository, and no project depends on it.
Global rules, `serial_capture.py` and the scaffold reach a project only through
`~/.cline/`, which any machine can reproduce from this repo.

Projects reference **tools**, never this repo:

```text
correct:  python "$env:USERPROFILE\.cline\tools\serial_capture.py" COM3 30
wrong:    python "D:\cline-setup\config\tools\serial_capture.py" COM3 30
```

A project pointing at `D:\cline-setup` directly would break on the next clone
elsewhere, and would survive deleting `~/.cline` - exactly the coupling this
repo exists to remove.

### Machine inventory on this PC

Reference only; `gen-machine-md.ps1` is what writes `~/.cline/rules/machine.md`.

| Item | Value |
|---|---|
| Node.js | v25.3.0 (nvm4w) |
| Python | 3.11.9 |
| PHP | 8.2.12 (XAMPP) |
| Git | 2.55.0 |
| Cline CLI | 3.0.60 |
| **ESP-IDF (active)** | `D:\esp32-tools\esp-idf` v5.3.2 - installer-registered |
| ESP-IDF (other) | `D:\esp32\v6.1\esp-idf` v6.1 |
| Serial ports | COM3, COM5 |
| Project repos | `D:\esp-idf`, `D:\esp32 audio`, `D:\New folder\cantwait`, `D:\dextop\tempn` |

> **Two ESP-IDF checkouts is a live hazard.** Every command must name the active
> one explicitly. `gen-machine-md.ps1` refuses to guess and marks the choice
> UNVERIFIED when the installer record is missing.

## Author

Nadeem <zahid_printers@yahoo.com> - MIT