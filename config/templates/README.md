# New Project

Creates a project with the standard layout, git, gitignore, and a starter
architecture map.

## Usage
    pwsh -File new-project.ps1 -Name my-project
    pwsh -File new-project.ps1 -Name my-project -Root D:\projects -Init

## Parameters
    -Name   Project folder name (required)
    -Root   Where to create it (default: current directory)
    -Init   Run `git init` and make the first commit

## What it creates
    <name>/
      docs/ARCHITECTURE.md   the map - start here
      src/                   code
      tests/                 tests
      temp/                  scratch (gitignored)
      logs/                  run/build/serial logs (gitignored)
      .gitignore
      README.md
      CHANGELOG.md
