-- Copyright Core DF — Apache License 2.0
local result = require("result")

local M = {}

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function M.LocalRead(path, encoding)
  encoding = encoding or "utf-8"
  if encoding ~= "utf-8" then
    return { status_code = 500, error = "unsupported encoding: " .. encoding }
  end
  local f, err = io.open(path, "r")
  if not f then return { status_code = 500, error = err or "open failed" } end
  local content = f:read("*a")
  f:close()
  return { status_code = 200, content = content or "" }
end

function M.LocalWrite(path, content, encoding)
  encoding = encoding or "utf-8"
  if encoding ~= "utf-8" then
    return { status_code = 500, error = "unsupported encoding: " .. encoding }
  end
  local dir = path:match("^(.*)/[^/]+$")
  if dir and dir ~= "" then
    os.execute("mkdir -p " .. shell_quote(dir))
  end
  local f, err = io.open(path, "w")
  if not f then return { status_code = 500, error = err or "write failed" } end
  f:write(content or "")
  f:close()
  return { status_code = 200 }
end

function M.LocalMove(src, dest)
  local ok, err = os.rename(src, dest)
  if ok then return { status_code = 200 } end
  return { status_code = 500, error = err or "rename failed" }
end

return M
