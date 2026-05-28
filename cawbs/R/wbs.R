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
# Shared HTTP helpers for the Core Auto Collector (cawbs) R client.

.wbs_sess <- new.env(parent = emptyenv())
.wbs_sess$initialized <- FALSE
.wbs_sess$base_url <- ""
.wbs_sess$env <- ""
.wbs_sess$token <- ""

wbs_missing_env <- function(vars) {
  list(status_code = 601L, error = paste("Environment variables", vars, "should be defined"))
}

wbs_trim_url <- function(url) {
  gsub("^[/ ]+|[/ ]+$", "", url)
}

wbs_do_request <- function(method, url, headers = list(), body = NULL) {
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("install.packages('httr')")
  }
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("install.packages('jsonlite')")
  }
  hdrs <- httr::add_headers(.headers = unlist(headers))
  resp <- tryCatch({
    if (method == "GET") {
      httr::GET(url, hdrs)
    } else {
      httr::POST(url, hdrs, body = body, encode = "raw",
                 httr::content_type("application/json"))
    }
  }, error = function(e) NULL)
  if (is.null(resp)) {
    return(list(status_code = 0L, body = NULL, transport_error = TRUE))
  }
  code <- as.integer(httr::status_code(resp))
  text <- httr::content(resp, as = "text", encoding = "UTF-8")
  parsed <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
  list(status_code = code, body = parsed, transport_error = FALSE)
}

wbs_api_error <- function(status_code, body) {
  if (is.null(body)) {
    return(list(status_code = status_code, error = "inaccessible"))
  }
  list(status_code = status_code, error = body)
}

wbs_authenticate <- function(env, access_code, base_url) {
  if (isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 602L, error = "init already called"))
  }
  .wbs_sess$env <- env
  .wbs_sess$base_url <- wbs_trim_url(base_url)
  headers <- list(
    `Content-Type` = "application/json",
    Environment = env
  )
  todo <- jsonlite::toJSON(list(apiCode = access_code), auto_unbox = TRUE)
  out <- wbs_do_request("POST", paste0(.wbs_sess$base_url, "/v1/auth/apicode"), headers, todo)
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body$token)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  .wbs_sess$token <- out$body$token
  .wbs_sess$initialized <- TRUE
  list(status_code = out$status_code)
}

wbs_auth_headers <- function() {
  list(
    `Content-Type` = "application/json",
    Environment = .wbs_sess$env,
    Authorization = paste("Bearer", .wbs_sess$token)
  )
}

wbs_get_event_payload <- function(action_id) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  out <- wbs_do_request("GET", paste0(.wbs_sess$base_url, "/v1/rtevent/", action_id), wbs_auth_headers())
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  list(status_code = out$status_code, payload = out$body$payload)
}

wbs_put_step_payload <- function(action_id, step_name, payload) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  todo <- jsonlite::toJSON(
    list(actionId = action_id, stepname = step_name, payload = payload),
    auto_unbox = TRUE
  )
  out <- wbs_do_request("POST", paste0(.wbs_sess$base_url, "/v1/rtstep/payload"), wbs_auth_headers(), todo)
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  list(status_code = out$status_code)
}

wbs_get_step_payload <- function(action_id, step_name) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  url <- paste0(.wbs_sess$base_url, "/v1/rtstep/payload/", action_id, "/", step_name)
  out <- wbs_do_request("GET", url, wbs_auth_headers())
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  list(status_code = out$status_code, payload = out$body$payload)
}

wbs_get_keystore <- function(keylist) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  keys <- gsub(" ", "", keylist, fixed = TRUE)
  out <- wbs_do_request("GET", paste0(.wbs_sess$base_url, "/v1/keystore/", keys), wbs_auth_headers())
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  for (key in strsplit(keys, ",")[[1]]) {
    if (nchar(key) == 0) next
    if (is.null(out$body[[key]])) {
      return(list(status_code = 605L, error = paste0(key, " not found")))
    }
  }
  list(status_code = out$status_code, answer = out$body)
}

wbs_post_event <- function(event_name, payload, event_source = NULL) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  body <- list(eventName = event_name, payload = payload)
  if (!is.null(event_source)) {
    body$eventSource <- event_source
  }
  todo <- jsonlite::toJSON(body, auto_unbox = TRUE)
  out <- wbs_do_request("POST", paste0(.wbs_sess$base_url, "/v1/rtevent"), wbs_auth_headers(), todo)
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  list(status_code = out$status_code, payload = out$body)
}

wbs_get_event_status <- function(action_id) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  out <- wbs_do_request(
    "GET",
    paste0(.wbs_sess$base_url, "/v1/rtevent/status/", action_id),
    wbs_auth_headers()
  )
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  list(status_code = out$status_code, payload = out$body)
}

wbs_get_event_list <- function() {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  out <- wbs_do_request("GET", paste0(.wbs_sess$base_url, "/v1/rtevent/list"), wbs_auth_headers())
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  list(status_code = out$status_code, payload = out$body)
}

wbs_submit_flag <- function(name, system_name, source_system_name, date) {
  if (!isTRUE(.wbs_sess$initialized)) {
    return(list(status_code = 603L, error = "Init required"))
  }
  todo <- jsonlite::toJSON(
    list(
      name = name,
      systemName = system_name,
      sourceSystemName = source_system_name,
      date = date
    ),
    auto_unbox = TRUE
  )
  out <- wbs_do_request("POST", paste0(.wbs_sess$base_url, "/v1/flag"), wbs_auth_headers(), todo)
  if (isTRUE(out$transport_error)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  if (out$status_code >= 400L) {
    return(wbs_api_error(out$status_code, out$body))
  }
  if (is.null(out$body)) {
    return(list(status_code = out$status_code, error = "inaccessible"))
  }
  list(status_code = out$status_code, payload = out$body)
}
