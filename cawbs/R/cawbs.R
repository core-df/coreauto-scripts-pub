# Copyright (c) Core DF. All rights reserved.
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
