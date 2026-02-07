local M = {}

local function now()
  return vim.loop.hrtime() / 1e9
end

local start_timers = {}

local function start_tracking(file)
  if not file or file == "" then
    return
  end

  start_timers[file] = now()
  vim.notify(string.format("Started timing for %s", file), vim.log.levels.DEBUG)
end

local function stop_tracking(file)
  if not file or file == "" then
    return
  end

  local start_time = start_timers[file]
  if not start_time then
    return
  end

  local end_time = now()
  local elapsed_time = end_time - start_time

  start_timers[file] = nil

  vim.notify(string.format("Time spent on %s: %.2f seconds", file, elapsed_time), vim.log.levels.DEBUG)
end

function M.setup()
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
