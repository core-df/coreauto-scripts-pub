#!/usr/bin/env lua
-- Copyright (c) Core DF. All rights reserved.
--
-- Batch-oriented cawbs client for the Core Auto Collector.
--
-- Documentation: https://coreauto.coredf.com/resources

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return src:match("(.*/)") or "./"
end

local wbs = dofile(script_dir() .. "lib/wbs.lua")

local function getenv(name)
  local v = os.getenv(name)
  return v or ""
end

function Init()
  local env = getenv("ENV")
  local access_code = getenv("CA_ACCESS_CODE")
  local base_url = getenv("CA_WBS_URL")
  if env == "" or access_code == "" or base_url == "" then
    return wbs.missing_env("ENV, CA_ACCESS_CODE, CA_WBS_URL")
  end
  return wbs.authenticate(env, access_code, base_url)
end

function GetKeystore(keylist)
  return wbs.get_keystore(keylist)
end

return {
  Init = Init,
  GetKeystore = GetKeystore,
}
