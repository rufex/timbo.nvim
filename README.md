# Timbó

A lightweight Neovim plugin that tracks time spent in files and projects, storing data locally in SQLite.

## Features

- Tracks active editing time per file (pauses on focus loss)
- Associates entries with git repository and branch
- Stores data in a local SQLite database

## Requirements

- [sqlite.lua](https://github.com/kkharji/sqlite.lua)

## Installation

### lazy.nvim

```lua
{
  "rufex/timbo.nvim",
  dependencies = { "kkharji/sqlite.lua" },
  opts = {},
}
```

## Configuration

```lua
require("timbo").setup({
  db_path = vim.fn.stdpath("data") .. "/timbo.db", -- default
})
```

## Commands

`:Timbo <scope> [branch=<name>] [from=YYYY-MM-DD] [to=YYYY-MM-DD]`

**Scopes:**

| Scope | Description |
|---|---|
| `file` | Total time spent on the current file |
| `files` | Time breakdown per file in the current git repository |
| `total` | Total time spent in the current git repository |

**Optional filters:**

| Filter | Description |
|---|---|
| `branch=<name>` | Filter by branch name. Use `branch=.` for the current branch |
| `from=YYYY-MM-DD` | Start date filter (inclusive) |
| `to=YYYY-MM-DD` | End date filter (inclusive) |

**Examples:**

```vim
:Timbo file
:Timbo files
:Timbo total
:Timbo files branch=main
:Timbo files branch=. from=2025-01-01 to=2025-01-31
```
