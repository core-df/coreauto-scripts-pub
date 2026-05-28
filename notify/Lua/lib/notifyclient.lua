-- Copyright Core DF — Apache License 2.0
local result = require("result")
local json = require("json")

local M = {}

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function env(k)
  return os.getenv(k) or ""
end

local function post_json(url, payload)
  local body = json.encode(payload)
  local cmd = string.format(
    "curl -s -S -w '\\n%%{http_code}' -X POST -H %s -d %s %s",
    shell_quote("Content-Type: application/json"),
    shell_quote(body),
    shell_quote(url)
  )
  local fh = io.popen(cmd)
  if not fh then return result.transport_error("curl failed") end
  local raw = fh:read("*a")
  fh:close()
  local code_str = raw:match("(\n%d+)$")
  if not code_str then return result.transport_error("bad curl response") end
  local code = tonumber(code_str:match("(%d+)$")) or 0
  local resp_body = raw:sub(1, #raw - #code_str)
  if code >= 400 then
    return { status_code = code, error = resp_body }
  end
  if resp_body == "" then return { status_code = 200 } end
  local ok, parsed = pcall(json.decode, resp_body)
  if ok then return { status_code = 200, body = parsed } end
  return { status_code = 200, body = resp_body }
end

function M.Slack(text, webhook_url)
  local url = webhook_url
  if not url or url == "" then url = env("SLACK_WEBHOOK_URL") end
  if url == "" then return result.missing_env("SLACK_WEBHOOK_URL") end
  return post_json(url, { text = text })
end

function M.Teams(text, webhook_url)
  local url = webhook_url
  if not url or url == "" then url = env("TEAMS_WEBHOOK_URL") end
  if url == "" then return result.missing_env("TEAMS_WEBHOOK_URL") end
  return post_json(url, {
    ["@type"] = "MessageCard",
    ["@context"] = "http://schema.org/extensions",
    text = text,
  })
end

function M.PagerDuty(summary, routing_key, severity)
  local key = routing_key
  if not key or key == "" then key = env("PAGERDUTY_ROUTING_KEY") end
  if key == "" then return result.missing_env("PAGERDUTY_ROUTING_KEY") end
  return post_json("https://events.pagerduty.com/v2/enqueue", {
    routing_key = key,
    event_action = "trigger",
    payload = {
      summary = summary,
      severity = severity or "error",
      source = "coreauto-step",
    },
  })
end

function M.Email(subject, body, to_addrs, from_addr)
  local host = env("SMTP_HOST")
  local port = tonumber(env("SMTP_PORT")) or 587
  local user = env("SMTP_USER")
  local password = env("SMTP_PASSWORD")
  local sender = from_addr
  if not sender or sender == "" then sender = env("SMTP_FROM") end
  if sender == "" then sender = user end
  if host == "" or sender == "" then return result.missing_env("SMTP_HOST and SMTP_FROM (or from_addr)") end
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  if not f then return result.transport_error("temp file failed") end
  f:write(string.format("From: %s\nTo: %s\nSubject: %s\n\n%s", sender, to_addrs, subject, body or ""))
  f:close()
  local cmd = string.format("curl -s -S --url 'smtp://%s:%d' --mail-from %s --mail-rcpt %s --upload-file %s",
    host, port, shell_quote("<" .. sender .. ">"), shell_quote("<" .. to_addrs .. ">"), shell_quote(tmp))
  if user ~= "" and password ~= "" then
    cmd = cmd .. string.format(" --user %s:%s", shell_quote(user), shell_quote(password))
  end
  os.remove(tmp)
  local fh = io.popen(cmd .. " 2>&1")
  if not fh then return result.transport_error("curl smtp failed") end
  local out = fh:read("*a")
  fh:close()
  if out and out:match("[Ee]rror") then return result.transport_error(out) end
  return { status_code = 200 }
end

return M
