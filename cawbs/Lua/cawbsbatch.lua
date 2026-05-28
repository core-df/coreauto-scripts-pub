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
