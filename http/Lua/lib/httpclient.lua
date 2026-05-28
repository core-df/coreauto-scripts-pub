-- Copyright Core DF — Apache License 2.0
local result = require("result")
local json = require("json")
local http = {}

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function parse_body(raw)
  if not raw or raw == "" then return nil end
  local ok, parsed = pcall(json.decode, raw)
  if ok then return parsed end
  return raw
end

local function request(method, url, headers, body)
  local hdr_args = {}
  for k, v in pairs(headers or {}) do
    hdr_args[#hdr_args + 1] = "-H " .. shell_quote(k .. ": " .. v)
  end
  local body_arg = body and ("-d " .. shell_quote(body)) or ""
  local cmd = string.format("curl -s -S -w '\\n%%{http_code}' -X %s %s %s %s",
    method, table.concat(hdr_args, " "), body_arg, shell_quote(url))
  local fh = io.popen(cmd)
  if not fh then return result.transport_error("curl failed") end
  local raw = fh:read("*a")
  fh:close()
  local code_str = raw:match("(\n%d+)$")
  if not code_str then return result.transport_error("bad curl response") end
  local code = tonumber(code_str:match("(%d+)$")) or 0
  local resp_body = raw:sub(1, #raw - #code_str)
  local parsed = parse_body(resp_body)
  if code >= 400 then
    return { status_code = code, error = parsed or "inaccessible" }
  end
  return { status_code = code, body = parsed }
end

function http.Get(url, headers, params)
  if params then
    local qs = {}
    for k, v in pairs(params) do qs[#qs+1] = k .. "=" .. v end
    url = url .. (url:find("?") and "&" or "?") .. table.concat(qs, "&")
  end
  return request("GET", url, headers)
end

function http.Post(url, json_body, data, headers)
  headers = headers or {}
  local body
  if json_body then
    headers["Content-Type"] = headers["Content-Type"] or "application/json"
    body = json.encode(json_body)
  else body = data end
  return request("POST", url, headers, body)
end

function http.Put(url, json_body, headers)
  headers = headers or {}
  local body
  if json_body then
    headers["Content-Type"] = headers["Content-Type"] or "application/json"
    body = json.encode(json_body)
  end
  return request("PUT", url, headers, body)
end

function http.Delete(url, headers)
  return request("DELETE", url, headers)
end

return http
