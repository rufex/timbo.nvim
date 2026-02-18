local DB = {}

local sqlite = require("sqlite")

local db_instance

local function date_to_timestamp(date_str, end_of_day)
  local y, m, d = date_str:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  return os.time({
    year = tonumber(y),
    month = tonumber(m),
    day = tonumber(d),
    hour = end_of_day and 23 or 0,
    min = end_of_day and 59 or 0,
    sec = end_of_day and 59 or 0,
  })
end

local function build_query(scope, filters, project, file)
  local conditions = { "project = :project" }
  local params = { project = project }

  if filters.branch then
    table.insert(conditions, "branch = :branch")
    params.branch = filters.branch
  end

  if filters.from then
    table.insert(conditions, "timestamp >= :ts_from")
    params.ts_from = date_to_timestamp(filters.from, false)
  end

  if filters.to then
    table.insert(conditions, "timestamp <= :ts_to")
    params.ts_to = date_to_timestamp(filters.to, true)
  end

  if scope == "file" then
    table.insert(conditions, "file = :file")
    params.file = file
  end

  local where = table.concat(conditions, " AND ")

  local sql
  if scope == "files" then
    sql = "SELECT file, SUM(seconds) AS total FROM time_entries WHERE " .. where .. " GROUP BY file ORDER BY total DESC"
  else
    sql = "SELECT SUM(seconds) AS total FROM time_entries WHERE " .. where
  end

  return sql, params
end

function DB.init(db_path)
  db_instance = sqlite:open(db_path)
  db_instance:execute([[
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

function DB.insert_entry(project, branch, file, seconds)
  db_instance:eval(
    "INSERT INTO time_entries (project, branch, file, seconds, timestamp) VALUES(:project, :branch, :file, :seconds, :timestamp)",
    { project = project, branch = branch, file = file, seconds = seconds, timestamp = os.time() }
  )
end

function DB.query(scope, filters, project, file)
  local sql, params = build_query(scope, filters, project, file)
  return db_instance:eval(sql, params)
end

return DB
