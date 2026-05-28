-- Copyright Core DF — Apache License 2.0
local M = {}
function M.missing_env(vars)
  return { status_code = 601, error = "Environment variables " .. vars .. " should be defined" }
end
function M.transport_error(message)
  return { status_code = 0, error = message or "inaccessible" }
end
return M
