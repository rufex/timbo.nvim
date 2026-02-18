local DB = require("timbo.db")

local Tracker = {}

local function now()
  return vim.loop.hrtime() / 1e9
end

local start_timers = {}

function Tracker.is_trackable_file(file)
  if not file or file == "" then
    return false
  end
  if file:find("://") then
    return false
  end
  return true
end

function Tracker.git_info(file)
  local dir = vim.fn.fnamemodify(file, ":h")
  local escaped = vim.fn.shellescape(dir)
  local branch = vim.trim(vim.fn.system("git -C " .. escaped .. " branch --show-current 2>/dev/null"))
  local root = vim.trim(vim.fn.system("git -C " .. escaped .. " rev-parse --show-toplevel 2>/dev/null"))
  return branch, root
end

function Tracker.start(file)
  if not Tracker.is_trackable_file(file) then
    return
  end

  start_timers[file] = now()
  vim.notify(string.format("Started timing for %s", file), vim.log.levels.DEBUG)
end

function Tracker.stop(file)
  if not Tracker.is_trackable_file(file) then
    return
  end

  local start_time = start_timers[file]
  if not start_time then
    return
  end

  local elapsed = now() - start_time
  start_timers[file] = nil

  local branch, project = Tracker.git_info(file)

  DB.insert_entry(project, branch, file, elapsed)

  vim.notify(string.format("Time spent on %s: %.2f seconds", file, elapsed), vim.log.levels.DEBUG)
end

return Tracker
