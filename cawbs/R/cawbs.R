# Copyright Core DF
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Core Auto Web Services library (cawbs) — R client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

script_dir <- tryCatch({
  args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(args)) dirname(normalizePath(sub("^--file=", "", args[1]))) else "."
}, error = function(e) ".")
source(file.path(script_dir, "wbs.R"), local = FALSE)

Init <- function() {
  env <- Sys.getenv("ENV", unset = "")
  action_id <- Sys.getenv("ACTIONID", unset = "")
  access_code <- Sys.getenv("CA_ACCESS_CODE", unset = "")
  base_url <- Sys.getenv("CA_WBS_URL", unset = "")
  step_name <- Sys.getenv("STEPNAME", unset = "")
  if (env == "" || action_id == "" || access_code == "" || base_url == "" || step_name == "") {
    return(wbs_missing_env("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME"))
  }
  wbs_authenticate(env, access_code, base_url)
}

GetEventPayload <- function() {
  wbs_get_event_payload(Sys.getenv("ACTIONID", unset = ""))
}

PutStepPayload <- function(payload) {
  wbs_put_step_payload(Sys.getenv("ACTIONID", unset = ""), Sys.getenv("STEPNAME", unset = ""), payload)
}

GetStepPayload <- function(stepname) {
  wbs_get_step_payload(Sys.getenv("ACTIONID", unset = ""), stepname)
}

GetKeystore <- function(keylist) {
  wbs_get_keystore(keylist)
}
