# Isolation — one project must never leak into another

## Hard boundaries
- Work ONLY inside the current project root.
- Never read, write, or reference another project directory unless the user
  explicitly names it in this conversation.
- Never copy code from another project "to save time" without being asked.
- Do not assume you remember another project's API or schema. Check this project.

## Generated output stays in this project
- `temp/`         scratch files, throwaway experiments
- `logs/`         run logs, build output, serial captures, test output
- `test-results/` test artifacts
- `.playwright-mcp/` browser traces and screenshots

None of these are committed. They are per-project by construction.

## Absolute-path leak check (run this after any config/script work)
    Select-String -Path <the file> -Pattern '[A-Z]:\\'
Any match pointing outside the current project root is a leak. Replace it with a
path relative to the project root. Known past offender: the Playwright
`--output-dir` in the global MCP config was pinned to one specific project.

## Secrets
Never commit tokens, keys, or passwords. Put the value in a local `.env`
(gitignored), reference the variable name in docs and config, and state in the
handoff that a value must be supplied.

## Git
Never run without explicit approval in the current conversation:
`git reset --hard`, `git clean -fd`, `git push --force`, `git branch -D`,
`git checkout .`, `git stash drop`.
Never discard or overwrite the user's uncommitted changes.
Commit only when asked. Always show `git diff` and a summary first.
