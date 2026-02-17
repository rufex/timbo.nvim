# Timbó

A lightweight Neovim plugin that tracks time spent in files and projects, storing data locally in SQLite.

## Features

- Tracks active editing time per file (pauses on focus loss)
- Associates entries with git project and branch
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

| Command | Description |
|---|---|
| `:TimboCurrBuffAccum` | Total time spent on the current file |
| `:TimboCurrRepoAccum` | Time breakdown per file in the current git project |
