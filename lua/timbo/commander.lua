local DB = require("timbo.db")
local Tracker = require("timbo.tracker")
local Presenter = require("timbo.presenter")

local Commander = {}

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

local function timbo_command(opts)
  local scope, filters = parse_args(opts.fargs)
  if not scope then
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  local current_branch, project = Tracker.git_info(file)

  if not project or project == "" then
    vim.notify("Timbo: not inside a git project", vim.log.levels.ERROR)
    return
  end

  if filters ~= nil and filters.branch == "." then
    filters.branch = current_branch
  end

  if scope == "file" and not Tracker.is_trackable_file(file) then
    vim.notify("Timbo: current buffer is not a trackable file", vim.log.levels.WARN)
    return
  end

  local rows = DB.query(scope, filters, project, file)
  Presenter.show(scope, filters, project, rows)
end

function Commander.register_user_commands()
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

function Commander.register_event_listeners()
  local group = vim.api.nvim_create_augroup("Timbo", { clear = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    pattern = "*",
    callback = function(args)
      Tracker.stop(args.file)
    end,
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function(args)
      Tracker.start(args.file)
    end,
  })

  vim.api.nvim_create_autocmd("FocusLost", {
    group = group,
    pattern = "*",
    callback = function()
      Tracker.stop(vim.api.nvim_buf_get_name(0))
    end,
  })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    pattern = "*",
    callback = function()
      Tracker.start(vim.api.nvim_buf_get_name(0))
    end,
  })
end

return Commander
