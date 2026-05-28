# Copyright Core DF — Apache License 2.0
http_missing_env <- function(vars) list(status_code=601L, error=paste("Environment variables", vars, "should be defined"))
http_transport_error <- function(message="inaccessible") list(status_code=0L, error=message)

http_parse_body <- function(raw) {
  if (is.null(raw) || raw == "") return(NULL)
  out <- tryCatch(jsonlite::fromJSON(raw, simplifyVector=FALSE), error=function(e) raw)
  out
}

http_request <- function(method, url, headers=list(), body=NULL, params=NULL) {
  if (!requireNamespace("httr", quietly=TRUE)) stop("install.packages('httr')")
  if (!requireNamespace("jsonlite", quietly=TRUE)) stop("install.packages('jsonlite')")
  if (length(params)) {
    sep <- if (grepl("\\?", url, fixed=TRUE)) "&" else "?"
    url <- paste0(url, sep, paste(paste0(names(params),"=", params), collapse="&"))
  }
  hdrs <- httr::add_headers(.headers=unlist(headers))
  resp <- tryCatch({
    if (method == "GET") httr::GET(url, hdrs)
    else if (method == "DELETE") httr::DELETE(url, hdrs)
    else if (method == "PUT") httr::PUT(url, hdrs, body=body, encode="raw", httr::content_type("application/json"))
    else httr::POST(url, hdrs, body=body, encode="raw", httr::content_type("application/json"))
  }, error=function(e) NULL)
  if (is.null(resp)) return(http_transport_error())
  code <- as.integer(httr::status_code(resp))
  text <- httr::content(resp, as="text", encoding="UTF-8")
  parsed <- http_parse_body(text)
  if (code >= 400L) return(list(status_code=code, error=if (is.null(parsed)) "inaccessible" else parsed))
  list(status_code=code, body=parsed)
}

Get <- function(url, headers=NULL, params=NULL) http_request("GET", url, headers %||% list(), params=params)
Post <- function(url, json_body=NULL, data=NULL, headers=NULL) {
  headers <- headers %||% list(); body <- NULL
  if (!is.null(json_body)) { headers[["Content-Type"]] <- headers[["Content-Type"]] %||% "application/json"; body <- jsonlite::toJSON(json_body, auto_unbox=TRUE) }
  else if (!is.null(data)) body <- data
  http_request("POST", url, headers, body)
}
Put <- function(url, json_body=NULL, headers=NULL) {
  headers <- headers %||% list(); body <- NULL
  if (!is.null(json_body)) { headers[["Content-Type"]] <- headers[["Content-Type"]] %||% "application/json"; body <- jsonlite::toJSON(json_body, auto_unbox=TRUE) }
  http_request("PUT", url, headers, body)
}
Delete <- function(url, headers=NULL) http_request("DELETE", url, headers %||% list())
`%||%` <- function(a,b) if (is.null(a)) b else a
