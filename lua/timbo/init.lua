local DB = require("timbo.db")

local M = {}

local function now()
  return vim.loop.hrtime() / 1e9
end

local config = {
  db_path = vim.fn.stdpath("data") .. "/timbo.db",
}

local start_timers = {}

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

  DB.insert_entry(project, branch, file, elapsed)

  vim.notify(string.format("Time spent on %s: %.2f seconds", file, elapsed), vim.log.levels.DEBUG)
end

local function format_seconds(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  local s = math.floor(seconds % 60)
  if h > 0 then
    return string.format("%dh %dm %ds", h, m, s)
  elseif m > 0 then
    return string.format("%dm %ds", m, s)
  else
    return string.format("%ds", s)
  end
end

local function parse_args(fargs)
  local scope = fargs[1]
  local valid_scopes = { file = true, files = true, total = true }
  if not valid_scopes[scope] then
    vim.notify("Timbo: invalid scope '" .. tostring(scope) .. "'. Use: file, files, total", vim.log.levels.ERROR)
    return nil, nil
  end

  local filters = {}
  local date_pat = "^%d%d%d%d%-%d%d%-%d%d$"

  for i = 2, #fargs do
    local key, value = fargs[i]:match("^(%w+)=(.+)$")
    if key and value then
      filters[key] = value
    else
      vim.notify("Timbo: unrecognized argument '" .. fargs[i] .. "'", vim.log.levels.WARN)
    end
  end

  if filters.from and not filters.from:match(date_pat) then
    vim.notify("Timbo: 'from' must be YYYY-MM-DD, got: " .. filters.from, vim.log.levels.ERROR)
    return nil, nil
  end
  if filters.to and not filters.to:match(date_pat) then
    vim.notify("Timbo: 'to' must be YYYY-MM-DD, got: " .. filters.to, vim.log.levels.ERROR)
    return nil, nil
  end

  return scope, filters
end

local function format_results(scope, filters, project, rows)
  local lines = {}

  table.insert(lines, "Timbo — " .. vim.fn.fnamemodify(project, ":t"))
  table.insert(lines, "Scope  : " .. scope)
  table.insert(lines, "Branch : " .. (filters.branch or "(all)"))
  if filters.from then
    table.insert(lines, "From   : " .. filters.from)
  end
  if filters.to then
    table.insert(lines, "To     : " .. filters.to)
  end
  table.insert(lines, string.rep("─", 60))
  table.insert(lines, "")

  if scope == "files" then
    if not rows or #rows == 0 then
      table.insert(lines, "(no data)")
    else
      local max_len = 0
      for _, row in ipairs(rows) do
        local rel = row.file:gsub("^" .. vim.pesc(project) .. "/", "")
        if #rel > max_len then
          max_len = #rel
        end
      end
      max_len = math.min(max_len, 60)
      for _, row in ipairs(rows) do
        local rel = row.file:gsub("^" .. vim.pesc(project) .. "/", "")
        table.insert(lines, string.format("  %-" .. max_len .. "s  %s", rel, format_seconds(row.total or 0)))
      end
    end
  else
    local total = rows and rows[1] and rows[1].total or 0
    table.insert(lines, "Total: " .. format_seconds(total))
  end

  return lines
end

local function open_scratch_buffer(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.cmd("split")
  vim.api.nvim_win_set_buf(vim.api.nvim_get_current_win(), buf)
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, noremap = true, silent = true })
end

local function timbo_command(opts)
  local scope, filters = parse_args(opts.fargs)
  if not scope then
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  local current_branch, project = git_info(file)

  if not project or project == "" then
    vim.notify("Timbo: not inside a git project", vim.log.levels.ERROR)
    return
  end

  if filters.branch == "." then
    filters.branch = current_branch
  end

  if scope == "file" and not is_trackable_file(file) then
    vim.notify("Timbo: current buffer is not a trackable file", vim.log.levels.WARN)
    return
  end

  local rows = DB.query(scope, filters, project, file)
  local lines = format_results(scope, filters, project, rows)
  open_scratch_buffer(lines)
end

local function register_user_commands()
  vim.api.nvim_create_user_command("Timbo", timbo_command, {
    nargs = "+",
    desc = ":Timbo <file|files|total> [branch=X] [from=YYYY-MM-DD] [to=YYYY-MM-DD]",
    complete = function(arglead, cmdline, _)
      local tokens = vim.split(cmdline, "%s+")
      if #tokens <= 2 then
        return vim.tbl_filter(function(s)
          return s:find("^" .. arglead) ~= nil
        end, { "file", "files", "total" })
      end
      return vim.tbl_filter(function(s)
        return s:find("^" .. arglead) ~= nil
      end, { "branch=", "from=", "to=" })
    end,
  })
end

local function register_event_listeners()
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

  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    pattern = "*",
    callback = function()
      stop_tracking(vim.api.nvim_buf_get_name(0))
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    pattern = "*",
    callback = function()
      start_tracking(vim.api.nvim_buf_get_name(0))
    end,
  })
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  DB.init(config.db_path)

  register_user_commands()
  register_event_listeners()
end

return M
