local DB = require("timbo.db")
local Commander = require("timbo.commander")

local M = {}

local config = {
  db_path = vim.fn.stdpath("data") .. "/timbo.db",
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  DB.init(config.db_path)

  Commander.register_user_commands()
  Commander.register_event_listeners()
end

return M
