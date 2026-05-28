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
# Ingress-oriented cawbs client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

script_dir <- tryCatch({
  args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(args)) dirname(normalizePath(sub("^--file=", "", args[1]))) else "."
}, error = function(e) ".")
source(file.path(script_dir, "wbs.R"), local = FALSE)

Init <- function() {
  env <- Sys.getenv("ENV", unset = "")
  access_code <- Sys.getenv("CA_ACCESS_CODE", unset = "")
  base_url <- Sys.getenv("CA_WBS_URL", unset = "")
  if (env == "" || access_code == "" || base_url == "") {
    return(wbs_missing_env("ENV, CA_ACCESS_CODE, CA_WBS_URL"))
  }
  wbs_authenticate(env, access_code, base_url)
}

PostEvent <- function(event_name, payload, event_source = NULL) {
  r <- wbs_post_event(event_name, payload, event_source)
  if (!is.null(r$error)) {
    return(r)
  }
  js <- r$payload
  list(
    status_code = r$status_code,
    eventId = js$eventId,
    actionId = js$actionId,
    createdAt = js$createdAt
  )
}

GetEventStatus <- function(action_id) {
  r <- wbs_get_event_status(action_id)
  if (!is.null(r$error)) {
    return(r)
  }
  list(status_code = r$status_code, status = r$payload)
}

GetEventList <- function() {
  r <- wbs_get_event_list()
  if (!is.null(r$error)) {
    return(r)
  }
  list(status_code = r$status_code, events = r$payload)
}

SubmitFlag <- function(name, system_name, source_system_name, date) {
  r <- wbs_submit_flag(name, system_name, source_system_name, date)
  if (!is.null(r$error)) {
    return(r)
  }
  list(status_code = r$status_code, flagStatus = r$payload$status)
}

GetKeystore <- function(keylist) {
  wbs_get_keystore(keylist)
}
