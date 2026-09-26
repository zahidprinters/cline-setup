# Cline Global Setup

Portable, tested configuration for a Cline working environment: global rules,
guard plugins, a project scaffold, and the MCP servers that are worth having.

Everything here was **verified by running it**, not by configuring it. Where a
claim is unverified, this README says so.

## Install on a new machine

```powershell
git clone <this-repo-url> cline-setup
cd cline-setup
pwsh -File install.ps1
pwsh -File gen-machine-md.ps1      # probes THIS machine, writes rules/machine.md
pwsh -File verify.ps1              # confirms the install
```

Then, once:

```powershell
cline plugin install branch-protector
cline plugin install env-blocker
pwsh -File patch-branch-protector.ps1    # the shipped fix — see docs/PLUGIN-PATCH.md
```

**Restart Cline afterwards.** VS Code: `Developer > Reload Window`.

Works for both the **Cline CLI** and the **VS Code extension** — they share
`~/.cline/`, so there is nothing separate to install.

## What you get

| Piece | What it does |
|---|---|
| `rules/` | 4 portable rules: task loop, project isolation, docs standard, lazy-dev mode |
| `rules/machine.md` | **generated**, never shipped — toolchain paths for this machine only |
| `tools/serial_capture.py` | non-interactive serial capture; `idf.py monitor` hangs a script |
| `templates/` | `new-project.ps1` scaffold + gitignore + architecture map + memory bank |
| `plugins/` | two guard plugins, one of them patched (see below) |
| `mcp/` | Context7 + Playwright. No secrets. |

## Design decisions

**`machine.md` is generated, not copied.** It records paths like
`D:\esp32-tools\esp-idf`. Shipping that to another machine would produce rules
that lie. `gen-machine-md.ps1` probes instead, and refuses to guess silently if
several ESP-IDF checkouts exist.

**The installer never clobbers an existing MCP config.** It backs yours up and
tells you where the new one is. Config that already exists is usually
deliberate.

**`branch-protector` ships patched.** The official plugin is broken; the fix and
the evidence are in `docs/PLUGIN-PATCH.md`. `patch-branch-protector.ps1` applies
it and checks the hash.

**No secrets anywhere in this repo.** The MCP config ships without tokens. If
you add GitHub MCP, keep the PAT in an environment variable, not in a file.

## Measured cost

```
Cline floor (system prompt + tools + MCPs)   6,990 tokens
Global rules (4 portable + machine.md)        4,471 tokens
                                             ---------
Request before any project file is read       11,461 tokens
```

Three runs per arm, zero variance. The floor is the real reason to keep the MCP
list short — every server added raises it permanently.

## Scripts

| Script | Does |
|---|---|
| `install.ps1` | copies config into `~/.cline`, backs up first, safe to re-run |
| `gen-machine-md.ps1` | probes this machine → `rules/machine.md` (`-Force` to overwrite) |
| `verify.ps1` | read-only health check; exit 1 on failure |
| `patch-branch-protector.ps1` | applies the plugin fix, verifies by SHA-256 (`-Revert` to undo) |

## New projects

```powershell
pwsh -File "$env:USERPROFILE\.cline\templates\new-project.ps1" `
    -Name my-sensor -Root D:\projects -Description "what it does" -Init
```

Creates `docs/ARCHITECTURE.md`, `memory-bank/`, `src/`, `tests/`, `temp/`,
`logs/`, a correct `.gitignore`, a `LICENSE`, `project.json`, and a first
commit.

## Skills

Not shipped — install per machine, they are large and opinionated:

```powershell
cline skill install cline/skills --skill review-team
```

## Troubleshooting

**`verify.ps1` says branch-protector hash differs.** A Cline update replaced
the patch. Do **not** assume it regressed — read `docs/PLUGIN-PATCH.md` and run
the six live tests first. Upstream may have fixed it properly.

**Rules do not seem to load.** Confirm `~/.cline/rules/` exists and restart
Cline. Global rules are shared with the VS Code extension, so there is no
separate extension-side setup.

**`idf.py` behaves oddly.** You may have more than one ESP-IDF checkout. Check
the "Other ESP-IDF checkouts" section of `rules/machine.md` and always name the
active path.

## Author

Nadeem <zahid_printers@yahoo.com> · MIT
