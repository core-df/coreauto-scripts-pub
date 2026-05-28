# Copyright Core DF — Apache License 2.0

file_missing_env <- function(vars) list(status_code = 601L, error = paste("Environment variables", vars, "should be defined"))
file_transport_error <- function(message = "inaccessible") list(status_code = 0L, error = message)

LocalRead <- function(path, encoding = "utf-8") {
  tryCatch({
    content <- paste(readLines(path, encoding = encoding, warn = FALSE), collapse = "\n")
    list(status_code = 200L, content = content)
  }, error = function(e) list(status_code = 500L, error = e$message))
}

LocalWrite <- function(path, content, encoding = "utf-8") {
  tryCatch({
    dir <- dirname(path)
    if (nzchar(dir) && dir != ".") dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    con <- file(path, open = "w", encoding = encoding)
    on.exit(close(con), add = TRUE)
    writeLines(content, con, useBytes = FALSE)
    list(status_code = 200L)
  }, error = function(e) list(status_code = 500L, error = e$message))
}

LocalMove <- function(src, dest) {
  tryCatch({
    file.rename(src, dest)
    list(status_code = 200L)
  }, error = function(e) list(status_code = 500L, error = e$message))
}
