#!/usr/bin/env lua
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
-- Ingress-oriented cawbs client for the Core Auto Collector.
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

function PostEvent(event_name, payload, event_source)
  local r = wbs.post_event(event_name, payload, event_source)
  if r.error then return r end
  local js = r.payload
  return {
    status_code = r.status_code,
    eventId = js.eventId,
    actionId = js.actionId,
    createdAt = js.createdAt,
  }
end

function GetEventStatus(action_id)
  local r = wbs.get_event_status(action_id)
  if r.error then return r end
  return { status_code = r.status_code, status = r.payload }
end

function GetEventList()
  local r = wbs.get_event_list()
  if r.error then return r end
  return { status_code = r.status_code, events = r.payload }
end

function SubmitFlag(name, system_name, source_system_name, date)
  local r = wbs.submit_flag(name, system_name, source_system_name, date)
  if r.error then return r end
  return { status_code = r.status_code, flagStatus = r.payload.status }
end

function GetKeystore(keylist)
  return wbs.get_keystore(keylist)
end

return {
  Init = Init,
  PostEvent = PostEvent,
  GetEventStatus = GetEventStatus,
  GetEventList = GetEventList,
  SubmitFlag = SubmitFlag,
  GetKeystore = GetKeystore,
}
