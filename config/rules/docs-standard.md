# Documentation standard — every project

## The map: `docs/ARCHITECTURE.md`
Exists so nobody re-reads the whole project to learn one thing.
It is a map, not a manual. Keep it accurate and short.

- **Purpose** — one paragraph: what this project does.
- **Stack** — language, framework, exact versions, target hardware.
- **Layout** — what each top-level folder holds.
- **Key modules** — name, file, one line on its responsibility.
- **Data/control flow** — how the pieces connect end to end.
- **Decisions** — notable choices and the reason. Append, never rewrite history.
- **Gotchas** — things that will bite the next person.

Update it whenever structure, flow, dependencies, or decisions change.

## Comments — what actually works
Comments on every line go stale within a week and bury the ones that matter.
The standard is:

- Every function carries one short comment: what it does, what it returns,
  and what it does NOT handle.
- Comment the **why**, not the **what**. The code already says what it does.
- Comment anything non-obvious: hardware pin numbers, magic numbers, units,
  timing constraints, register names, protocol fields, workarounds.
- Do not restate the syntax. `i++ // increment i` is noise — delete it.
- Do not comment out code. Delete it; git remembers.

A good comment answers "why did they do it this way", not "what does this line do".

## `CHANGELOG.md`
Append-only, newest at top. One entry per completed task:

    ## 2026-09-25 — Short title
    - What changed
    - Why
    - Tested: exact commands run + result
    - Not tested: what remains unverified

Never edit an old entry to make history look better.

## `templates/gitignore` — the shared stack rules
One source of truth for every project, covering ESP-IDF, Arduino, C/C++, Python,
PHP, Node/JS, and web output. Sectioned with `# ---------- name ----------`
headers so a project can delete the sections it does not use.

The scaffold copies it. **Do not hand-write a `.gitignore`**; if a rule is
missing, add it to the template so the next project gets it too.

Deliberate exceptions worth knowing:
- `sdkconfig` IS committed (it is project config); `sdkconfig.old` is not.
- `.env.example` / `.sample` / `.template` ARE committed; `.env` is not.
- `.cline/rules/` is NOT ignored — project rules are documentation.
- `temp/`, `logs/`, `test-results/`, `.playwright-mcp/` are always ignored.

## Keeping it current as the project grows
The ignore rules must change on the same day as the dependency that needs them.
Not at the end of the sprint, not when `git status` gets noisy.

When you add any of these, extend `.gitignore` **and** the template in the same
change:

| Adding | Add to gitignore |
|---|---|
| A dependency manager | its build/cache dirs (`node_modules/`, `vendor/`, `target/`) |
| A new language | its section in the template |
| A secret | the file, **and** confirm the negation for the example file |
| A tool that writes output | its output dir (`dist/`, `coverage/`, `.pytest_cache/`) |
| A new IDE or OS artifact | the dotfile |

**ponytail:** the ceiling here is that this is a fixed list, not a generator. A
project that outgrows it should be re-scanned with `git status --ignored` and the
template updated once, not section by section forever.

## Before ending a task
- [ ] `docs/ARCHITECTURE.md` current
- [ ] `CHANGELOG.md` entry added
- [ ] `README.md` still accurate for anyone new
- [ ] Anything unverified stated explicitly in the handoff
