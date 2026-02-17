local M = {}

local sqlite = require("sqlite")

local function now()
  return vim.loop.hrtime() / 1e9
end

local config = {
  db_path = vim.fn.stdpath("data") .. "/timbo.db",
}

local db
local start_timers = {}

local function init_db()
  db = sqlite:open(config.db_path)
  db:execute([[
    CREATE TABLE IF NOT EXISTS time_entries (
      id      INTEGER PRIMARY KEY AUTOINCREMENT,
      project TEXT,
      branch  TEXT,
      file    TEXT,
      seconds REAL NOT NULL,
      timestamp INTEGER NOT NULL
    )
  ]])
end

local function is_trackable_file(file)
  if not file or file == "" then
    return false
  end
  if file:find("://") then
    return false
  end
  return true
end

local function git_info(file)
  local dir = vim.fn.fnamemodify(file, ":h")
  local escaped = vim.fn.shellescape(dir)
  local branch = vim.trim(vim.fn.system("git -C " .. escaped .. " branch --show-current 2>/dev/null"))
  local root = vim.trim(vim.fn.system("git -C " .. escaped .. " rev-parse --show-toplevel 2>/dev/null"))
  return branch, root
end

local function start_tracking(file)
  if not is_trackable_file(file) then
    return
  end

  start_timers[file] = now()
  vim.notify(string.format("Started timing for %s", file), vim.log.levels.DEBUG)
end

local function stop_tracking(file)
  if not is_trackable_file(file) then
    return
  end

  local start_time = start_timers[file]
  if not start_time then
    return
  end

  local elapsed = now() - start_time
  start_timers[file] = nil

  local branch, project = git_info(file)

  db:eval(
    "INSERT INTO time_entries (project, branch, file, seconds, timestamp) VALUES(:project, :branch, :file, :seconds, :timestamp)",
    { project = project, branch = branch, file = file, seconds = elapsed, timestamp = os.time() }
  )

  vim.notify(string.format("Time spent on %s: %.2f seconds", file, elapsed), vim.log.levels.DEBUG)
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  init_db()

  local group = vim.api.nvim_create_augroup("Timbo", { clear = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    pattern = "*",
    callback = function(args)
      stop_tracking(args.file)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function(args)
      start_tracking(args.file)
    end,
  })
end

return M
