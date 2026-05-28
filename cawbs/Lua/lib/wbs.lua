-- Copyright Core DF

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Shared HTTP helpers for the Core Auto Collector (cawbs) Lua client.
-- Uses curl (same approach as the Shell client).

local wbs = {}

wbs.initialized = false
wbs.base_url = ""
wbs.env = ""
wbs.token = ""

local function trim_url(url)
  return (url:gsub("^[/ ]+", ""):gsub("[/ ]+$", ""))
end

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function do_request(method, url, headers, body)
  local hdr_args = {}
  for k, v in pairs(headers) do
    hdr_args[#hdr_args + 1] = "-H " .. shell_quote(k .. ": " .. v)
  end
  local body_arg = ""
  if body then
    body_arg = "-d " .. shell_quote(body)
  end
  local cmd = string.format(
    "curl -s -S -w '\\n%%{http_code}' -X %s %s %s %s",
    method,
    table.concat(hdr_args, " "),
    body_arg,
    shell_quote(url)
  )
  local fh = io.popen(cmd)
  if not fh then
    return 0, nil, true
  end
  local raw = fh:read("*a")
  fh:close()
  if not raw or raw == "" then
    return 0, nil, true
  end
  local code_str = raw:match("(\n%d+)$")
  if not code_str then
    return 0, nil, true
  end
  local http_code = tonumber(code_str:match("(%d+)$")) or 0
  local resp_body = raw:sub(1, #raw - #code_str)
  local ok, parsed = pcall(function()
    if resp_body == "" then return nil end
    return wbs.decode_json(resp_body)
  end)
  if not ok then parsed = nil end
  return http_code, parsed, false
end

function wbs.missing_env(vars)
  return { status_code = 601, error = "Environment variables " .. vars .. " should be defined" }
end

function wbs.api_error(status_code, body)
  if body == nil then
    return { status_code = status_code, error = "inaccessible" }
  end
  return { status_code = status_code, error = body }
end

function wbs.authenticate(env, access_code, base_url)
  if wbs.initialized then
    return { status_code = 602, error = "init already called" }
  end
  wbs.env = env
  wbs.base_url = trim_url(base_url)
  local todo = wbs.encode_json({ apiCode = access_code })
  local code, body, transport = do_request("POST", wbs.base_url .. "/v1/auth/apicode", {
    ["Content-Type"] = "application/json",
    Environment = env,
  }, todo)
  if transport then
    return { status_code = code, error = "inaccessible" }
  end
  if code >= 400 then
    return wbs.api_error(code, body)
  end
  if type(body) ~= "table" or not body.token then
    return { status_code = code, error = "inaccessible" }
  end
  wbs.token = body.token
  wbs.initialized = true
  return { status_code = code }
end

local function auth_headers()
  return {
    ["Content-Type"] = "application/json",
    Environment = wbs.env,
    Authorization = "Bearer " .. wbs.token,
  }
end

function wbs.get_event_payload(action_id)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local code, body, transport = do_request("GET", wbs.base_url .. "/v1/rtevent/" .. action_id, auth_headers())
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if type(body) ~= "table" then return { status_code = code, error = "inaccessible" } end
  return { status_code = code, payload = body.payload }
end

function wbs.put_step_payload(action_id, step_name, payload)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local todo = wbs.encode_json({ actionId = action_id, stepname = step_name, payload = payload })
  local code, body, transport = do_request("POST", wbs.base_url .. "/v1/rtstep/payload", auth_headers(), todo)
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  return { status_code = code }
end

function wbs.get_step_payload(action_id, step_name)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local url = wbs.base_url .. "/v1/rtstep/payload/" .. action_id .. "/" .. step_name
  local code, body, transport = do_request("GET", url, auth_headers())
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if type(body) ~= "table" then return { status_code = code, error = "inaccessible" } end
  return { status_code = code, payload = body.payload }
end

function wbs.get_keystore(keylist)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local keys = keylist:gsub(" ", "")
  local code, body, transport = do_request("GET", wbs.base_url .. "/v1/keystore/" .. keys, auth_headers())
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if type(body) ~= "table" then return { status_code = code, error = "inaccessible" } end
  for key in keys:gmatch("[^,]+") do
    if key ~= "" and body[key] == nil then
      return { status_code = 605, error = key .. " not found" }
    end
  end
  return { status_code = code, answer = body }
end

function wbs.post_event(event_name, payload, event_source)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local body_tbl = { eventName = event_name, payload = payload }
  if event_source ~= nil then
    body_tbl.eventSource = event_source
  end
  local todo = wbs.encode_json(body_tbl)
  local code, body, transport = do_request("POST", wbs.base_url .. "/v1/rtevent", auth_headers(), todo)
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if type(body) ~= "table" then return { status_code = code, error = "inaccessible" } end
  return { status_code = code, payload = body }
end

function wbs.get_event_status(action_id)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local code, body, transport = do_request(
    "GET",
    wbs.base_url .. "/v1/rtevent/status/" .. tostring(action_id),
    auth_headers()
  )
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if type(body) ~= "table" then return { status_code = code, error = "inaccessible" } end
  return { status_code = code, payload = body }
end

function wbs.get_event_list()
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local code, body, transport = do_request("GET", wbs.base_url .. "/v1/rtevent/list", auth_headers())
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if body == nil then return { status_code = code, error = "inaccessible" } end
  return { status_code = code, payload = body }
end

function wbs.submit_flag(name, system_name, source_system_name, date)
  if not wbs.initialized then
    return { status_code = 603, error = "Init required" }
  end
  local todo = wbs.encode_json({
    name = name,
    systemName = system_name,
    sourceSystemName = source_system_name,
    date = date,
  })
  local code, body, transport = do_request("POST", wbs.base_url .. "/v1/flag", auth_headers(), todo)
  if transport then return { status_code = code, error = "inaccessible" } end
  if code >= 400 then return wbs.api_error(code, body) end
  if type(body) ~= "table" then return { status_code = code, error = "inaccessible" } end
  return { status_code = code, payload = body }
end

-- Minimal JSON encode/decode (requires no external deps; sufficient for cawbs payloads)
function wbs.encode_json(val)
  local t = type(val)
  if t == "nil" then return "null"
  elseif t == "boolean" then return val and "true" or "false"
  elseif t == "number" then return tostring(val)
  elseif t == "string" then
    return '"' .. val:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  elseif t == "table" then
    local is_array = #val > 0
    if is_array then
      local parts = {}
      for i = 1, #val do parts[#parts + 1] = wbs.encode_json(val[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for k, v in pairs(val) do
      parts[#parts + 1] = wbs.encode_json(tostring(k)) .. ":" .. wbs.encode_json(v)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

function wbs.decode_json(str)
  local pos = 1
  local function skip()
    while str:sub(pos, pos):match("%s") do pos = pos + 1 end
  end
  local parse_value
  local function parse_string()
    pos = pos + 1
    local start = pos
    local out = {}
    while pos <= #str do
      local c = str:sub(pos, pos)
      if c == '"' then
        table.insert(out, str:sub(start, pos - 1))
        pos = pos + 1
        return table.concat(out)
      elseif c == "\\" then
        table.insert(out, str:sub(start, pos - 1))
        pos = pos + 1
        local esc = str:sub(pos, pos)
        if esc == "n" then table.insert(out, "\n")
        elseif esc == "t" then table.insert(out, "\t")
        elseif esc == "r" then table.insert(out, "\r")
        else table.insert(out, esc) end
        pos = pos + 1
        start = pos
      else
        pos = pos + 1
      end
    end
    error("bad string")
  end
  local function parse_number()
    local start = pos
    while str:sub(pos, pos):match("[%d%.eE%-%+]") do pos = pos + 1 end
    return tonumber(str:sub(start, pos - 1))
  end
  function parse_value()
    skip()
    local c = str:sub(pos, pos)
    if c == '"' then return parse_string()
    elseif c == "{" then
      pos = pos + 1
      local obj = {}
      skip()
      if str:sub(pos, pos) == "}" then pos = pos + 1 return obj end
      while true do
        skip()
        local key = parse_string()
        skip()
        pos = pos + 1
        obj[key] = parse_value()
        skip()
        local ch = str:sub(pos, pos)
        pos = pos + 1
        if ch == "}" then break end
      end
      return obj
    elseif c == "[" then
      pos = pos + 1
      local arr = {}
      skip()
      if str:sub(pos, pos) == "]" then pos = pos + 1 return arr end
      while true do
        arr[#arr + 1] = parse_value()
        skip()
        local ch = str:sub(pos, pos)
        pos = pos + 1
        if ch == "]" then break end
      end
      return arr
    elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
    elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
    elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
    else return parse_number() end
  end
  return parse_value()
end

return wbs
