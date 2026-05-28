-- Copyright Core DF — Apache License 2.0
-- Uses AWS CLI (aws) on PATH for S3 operations.
local result = require("result")

local M = {}

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function env(k, fallback)
  local v = os.getenv(k)
  if v and v ~= "" then return v end
  return fallback or ""
end

local function bucket(explicit)
  if explicit and explicit ~= "" then return explicit end
  return env("S3_BUCKET")
end

local function aws_base()
  local region = env("AWS_REGION", env("AWS_DEFAULT_REGION", "us-east-1"))
  local endpoint = env("S3_ENDPOINT_URL")
  local parts = { "aws", "--region", shell_quote(region) }
  if endpoint ~= "" then
    parts[#parts + 1] = "--endpoint-url"
    parts[#parts + 1] = shell_quote(endpoint)
  end
  return table.concat(parts, " ")
end

local function run(cmd)
  local fh = io.popen(cmd .. " 2>&1")
  if not fh then return nil, "command failed" end
  local out = fh:read("*a")
  local ok = fh:close()
  if ok then return out, nil end
  return out, out
end

function M.Init()
  if env("AWS_ACCESS_KEY_ID") == "" and env("AWS_PROFILE") == "" then
    return result.missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
  end
  if env("S3_BUCKET") == "" then
    return result.missing_env("S3_BUCKET (or pass bucket per call)")
  end
  return { status_code = 200 }
end

function M.GetObject(key, bucket_name)
  local b = bucket(bucket_name)
  if b == "" then return result.missing_env("S3_BUCKET") end
  local cmd = string.format("%s s3 cp s3://%s/%s -", aws_base(), b, key)
  local out, err = run(cmd)
  if err then return result.transport_error(err) end
  return { status_code = 200, content = out or "" }
end

function M.PutObject(key, content, bucket_name)
  local b = bucket(bucket_name)
  if b == "" then return result.missing_env("S3_BUCKET") end
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  if not f then return result.transport_error("temp file failed") end
  f:write(content or "")
  f:close()
  local cmd = string.format("%s s3 cp %s s3://%s/%s", aws_base(), shell_quote(tmp), b, key)
  local _, err = run(cmd)
  os.remove(tmp)
  if err then return result.transport_error(err) end
  return { status_code = 200 }
end

function M.ListObjects(prefix, bucket_name)
  local b = bucket(bucket_name)
  if b == "" then return result.missing_env("S3_BUCKET") end
  prefix = prefix or ""
  local uri = "s3://" .. b .. "/"
  if prefix ~= "" then uri = uri .. prefix end
  local cmd = string.format("%s s3 ls %s --recursive", aws_base(), shell_quote(uri))
  local out, err = run(cmd)
  if err then return result.transport_error(err) end
  local keys = {}
  for line in (out or ""):gmatch("[^\r\n]+") do
    local key = line:match("%S+%s+%S+%s+%S+%s+(.+)$")
    if key then keys[#keys + 1] = key end
  end
  return { status_code = 200, keys = keys }
end

return M
