# Workflow — phases, task size, test discipline

## Task size
One task = one verifiable change. If you cannot describe how to verify it in a
single sentence, the task is too big — split it and do them in order.

Never bundle "refactor + add feature + fix bug" into one pass.

## Starting a new project
Do not invent a folder layout. Use the scaffold:

    pwsh -NoProfile -File "$env:USERPROFILE\.cline\templates\new-project.ps1" -Name <name> -Root <parent> -Init

It creates `docs/`, `src/`, `tests/`, `temp/`, `logs/`, a `.gitignore` that
already excludes scratch/logs/secrets, `README.md`, `CHANGELOG.md`, and the map
at `docs/ARCHITECTURE.md`, then makes the first git commit.

Then fill in `docs/ARCHITECTURE.md` (Purpose, Stack, Layout) before writing code.

## The loop
PLAN -> BUILD -> SELF-TEST -> HAND OFF -> USER-TEST -> UPDATE DOCS

1. PLAN   - state the change in one sentence and say how you will verify it.
            Do not write code yet.
2. BUILD  - smallest change that solves the problem. Reuse before writing.
3. SELF-TEST - you run it. Build it, run it, read the output.
            "Looks right" is not a test.
4. HAND OFF - tell the user exactly: what changed, what you ran, the actual
            output, and what you did NOT test. Never claim a test you did not run.
5. USER-TEST - the user confirms in the real app. If they report a failure,
            capture the FULL output before changing any code.
6. UPDATE DOCS - docs/ARCHITECTURE.md and CHANGELOG.md are current
            before the task is called done.

A task is not done with failing or unrun tests.

## Phases
- PLAN       design only, no edits
- DEV        implementation
- TEST       automated + manual verification
- PRODUCTION release: docs complete, no debug code, changelog written, clean history

## Before ending any task
- [ ] Did I actually run it? Paste the real output.
- [ ] docs/ARCHITECTURE.md updated if structure/flow/decisions changed
- [ ] CHANGELOG.md has an entry
- [ ] git status shows no stray files (temp/, logs/, .playwright-mcp/ must not be committed)
- [ ] I stated clearly what was tested and what was not

## Serial / boot log capture
`idf.py monitor` is interactive and will hang a non-interactive shell. Use the
global helper instead — it exits on its own and is safe to script:

    python "$env:USERPROFILE\.cline\tools\serial_capture.py" COM3 30 > logs\boot.log

Read the full log before forming a theory. A truncated log produces a wrong fix.

## Memory Bank — the project-level memory that survives my context

I lose everything between sessions. So does the context window mid-task. The
`docs/ARCHITECTURE.md` map covers *structure*; Memory Bank covers *intent* —
what we decided, what we tried, what failed, what is next.

**Read the Memory Bank files at the start of any task on a project that has
them.** If `memory-bank/` exists, read at least `activeContext.md` and
`progress.md` before touching code. This is not optional.

### Structure
```
memory-bank/
├── projectbrief.md    what this project is, hard requirements
├── productContext.md  why it exists, problems it solves, UX goals
├── activeContext.md   current focus, recent changes, next steps  <- changes most
├── systemPatterns.md  architecture, design decisions, component relationships
├── techContext.md     stack, setup, constraints, dependencies
└── progress.md        what works, what is left, known issues
```

### Commands (plain language, not slash commands)
- `"update memory bank"` — review **all** files and refresh. Run this before a
  context window fills up, so the knowledge survives into the next session.
- `"follow your custom instructions"` — reload the bank at session start.
- `"initialize memory bank"` — create the structure for a new project.

### Rules
- Update `activeContext.md` **after each session**; `progress.md` at milestones.
- `activeContext.md` is where "what did we just try and what happened" lives.
  Failed attempts are as valuable as successful ones — write them down so the
  next session does not repeat them.
- Never let the bank drift from reality. A stale memory bank is worse than none,
  because I will trust it.
- The bank is **project** level, never global. One bank's project facts are
  meaningless in another project.

**ponytail:** this overlaps `docs/ARCHITECTURE.md` on purpose but the split
matters. ARCHITECTURE.md = what the code *is* (read to navigate). Memory Bank =
what we *decided and why* (read to continue). Merging them makes both worse.

## Conditional rules — load language rules only when relevant

A rule file starting with YAML frontmatter `paths:` activates only when a
matching file is in context. This is how you avoid paying for ESP32 guidance
in a PHP project.

```markdown
---
paths:
  - "firmware/**/*.c"
  - "firmware/**/CMakeLists.txt"
---
# ESP32 rules go here
```

Use it for project-level rules (`esp32.md`, `php.md`, `web.md`, `python.md`).
Files with **no** frontmatter are always active — keep universal rules in
those, scoped ones behind `paths:`.

## Author & License — one identity, machine-wide

**Canonical author: `Nadeem <zahid_printers@yahoo.com>`** (set in
`git config --global`, so every commit is attributed correctly by default).

Every new project gets author, description, and a LICENSE automatically:

    pwsh -File "$env:USERPROFILE\.cline\templates\new-project.ps1" `
        -Name my-app -Description "one line: what it does" -License MIT -Init

That writes `LICENSE` (with a correct SPDX id) and `project.json` holding
`name`, `description`, `author`, `license`, `created`. Do not hand-write
these; do not add a second author block.

**License default: MIT.** All five existing repos are MIT, so MIT is the
consistent choice. Override with `-License Apache-2.0 | GPL-3.0 | Unlicense |
Proprietary`. For `Proprietary`, replace the generated file with real terms —
the generated one is a marker, not legal text.

### Why this rule exists — the drift is real
As of 2026-09-26 the five repos on this machine carry **six** different
author identities and three different copyright holders:

| Identity | Where it came from |
|---|---|
| `Nadeem <zahid_printers@yahoo.com>` | ✅ canonical — 1,387 commits |
| `zahidprinters <zahidprintersraiwind@gmail.com>` | ⚠️ a second account, 54 commits |
| `ESP32 AudioNode Dev <dev@esp32-audio-node.local>` | invented placeholder |
| `cline <cline@audio-node.local>` | invented placeholder |
| `Cline <cline@local>` | invented placeholder |
| `audio-dev <dev@local>` | invented placeholder |

Copyright lines disagree too: `Nadeem`, `Nadeem Abbas`, and `CantWait`.
`D:\esp32 audio` has no LICENSE at all.

**Consequences:** GitHub will not link your second Gmail account to your
profile, so 54 commits show as an unrelated contributor. The `.local` and
`@local` identities are fake — they can never be verified or claimed.

### Rules
- **Never invent an author, email, or company name.** If it is not known, use
  the canonical identity or leave a `TODO:`. A fake identity is worse than none.
- **Never set a per-repo `user.name`/`user.email`** unless the user explicitly
  asks for a different identity for that repo.
- **Every new project needs a LICENSE** before its first push.
- **Do not rewrite existing commit history** to fix attribution. `git filter-repo`
  changes every commit hash and breaks every existing clone and remote. Leave
  history alone; the canonical identity applies going forward.

**ponytail:** the ceiling here is that old commits keep their wrong identity
forever. Fixing that costs a history rewrite plus re-cloning every remote, which
is destructive and not worth it for 54 commits. If a public repo ever needs a
clean author, the fix is a fresh `git init` with an import commit, not a rewrite.

## Debugging
Capture the FULL output first — complete boot log, full stack trace, full error
message — before forming any theory. A truncated log produces a wrong fix.
When a bug is reported, fix the root cause in the shared function, not the
symptom at the call site.
