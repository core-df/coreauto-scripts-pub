# Copyright (c) Core DF. All rights reserved.
#
# Batch-oriented cawbs client for the Core Auto Collector.
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

GetKeystore <- function(keylist) {
  wbs_get_keystore(keylist)
}
