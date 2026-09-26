# branch-protector — known upstream defect and the fix

## The problem

The official `branch-protector` plugin is a **silent no-op** against the real
Cline runtime. It installs cleanly, registers a `beforeTool` hook, and does
nothing at all.

Two independent defects, both confirmed by reading the source and reproducing
them in live sessions:

**1. Input shape mismatch — the fatal one**

```ts
// plugin reads
const input = toolCall.input as { command?: string }
const command = input?.command
if (!command) return          // <-- always taken
```

```jsonc
// runtime actually sends
"input": { "commands": ["git push origin master"] }
```

`input.command` is `undefined` because the key is `commands`. The hook returns
before it ever evaluates a branch. Every real call falls through.

**2. Regex anchored to the start of the string**

```ts
/^\s*git\s+push\b/
```

`cd project && git push origin master` does not start with `git`, so it never
matches — even with a singular-string input.

**3. `context` may be undefined (found only in production)**

The first patched version used `context.cwd`. A live run failed with
`Cannot read properties of undefined (reading 'cwd')`, which aborted the whole
task. Fixed to `context?.cwd ?? process.cwd()`.

> This is why the harness was not enough. The unit tests passed 18/18 while the
> plugin was still broken in the real runtime.

## The evidence

Corrected harness, original vs patched, same matrix:

```
ORIGINAL   8/18
PATCHED   18/18
```

The single original case that *did* block was `command: "git push ..."` — the
singular-string shape, precisely the shape the runtime never sends.

## The fix

```ts
// accept every shape the runtime may use
const value = record.commands ?? record.command ?? record.cmd

// test every segment, not just the start of the line
command.split(/\s*(?:&&|\|\||;|\n|\|)\s*/).some(s => /^git\s+push\b/.test(s))
```

The guarded branch is the one **checked out**, not a refspec parsed from the
command — so a crafted refspec cannot smuggle a push past it.

## Apply

```powershell
pwsh -File patch-branch-protector.ps1
```

Prints the SHA-256 and compares it to the known-good value. Undo with
`-Revert` (ships the original, to prove the bug is real).

## Live tests — run these after any update

Use a disposable repo with a remote that does not exist, so even an unblocked
push cannot do damage.

```powershell
$repo = "$env:TEMP\bptest"
New-Item -ItemType Directory $repo -Force | Out-Null
Push-Location $repo
git init -q
git -c user.name=T -c user.email=t@t commit -q --allow-empty -m init
git branch -M master
git remote add origin https://github.com/nonexistent-xyz/definitely-not-real-abc123.git
```

Then, for each command, ask Cline to run it and look for
`branch-protector: refusing` in the output:

| Command | Expected |
|---|---|
| `git push origin master` | BLOCKED |
| `git push origin main` | BLOCKED |
| `git push origin release/test` | BLOCKED |
| `git push origin feature/test` | allowed (reaches git) |
| `cd bptest && git push origin master` | BLOCKED |
| `git push --force-allow origin master` | allowed (explicit bypass) |

`feature/test` must be **allowed** — a guard that blocks everything is not a
guard, it is an outage.

```powershell
Pop-Location; Remove-Item $repo -Recurse -Force
```

## Known-good marker

```
sha256 : 0F71EA0AE0786C691E75C5112E08CF4B2B7DA242D44A256C1AD91D57BA95171A
bytes  : 3343
```

After a Cline update the installed directory name changes (it is
hash-suffixed), so `verify.ps1` finds it by pattern. **If the hash changes, run
the live tests before reinstalling** — a new hash may be a genuine upstream fix.
