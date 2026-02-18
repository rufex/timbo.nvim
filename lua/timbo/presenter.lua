local Presenter = {}

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

function Presenter.show(scope, filters, project, rows)
  local lines = format_results(scope, filters, project, rows)
  open_scratch_buffer(lines)
end

return Presenter
