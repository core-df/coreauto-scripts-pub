#!/usr/bin/env lua
-- Copyright (c) Core DF. All rights reserved.
--
-- Core Auto Web Services library (cawbs) — Lua client for the Core Auto Collector.
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
  local action_id = getenv("ACTIONID")
  local access_code = getenv("CA_ACCESS_CODE")
  local base_url = getenv("CA_WBS_URL")
  local step_name = getenv("STEPNAME")
  if env == "" or action_id == "" or access_code == "" or base_url == "" or step_name == "" then
    return wbs.missing_env("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME")
  end
  return wbs.authenticate(env, access_code, base_url)
end

function GetEventPayload()
  return wbs.get_event_payload(getenv("ACTIONID"))
end

function PutStepPayload(payload)
  return wbs.put_step_payload(getenv("ACTIONID"), getenv("STEPNAME"), payload)
end

function GetStepPayload(stepname)
  return wbs.get_step_payload(getenv("ACTIONID"), stepname)
end

function GetKeystore(keylist)
  return wbs.get_keystore(keylist)
end

return {
  Init = Init,
  GetEventPayload = GetEventPayload,
  PutStepPayload = PutStepPayload,
  GetStepPayload = GetStepPayload,
  GetKeystore = GetKeystore,
}
