# Copyright Core DF — Apache License 2.0
script_dir <- tryCatch({
  args <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(args)) dirname(normalizePath(sub("^--file=", "", args[1]))) else "."
}, error = function(e) ".")
root <- normalizePath(file.path(script_dir, "../.."))

source(file.path(root, "cawbs/R/cawbs.R"))
source(file.path(root, "transform/R/transformclient.R"))
source(file.path(root, "files/R/fileclient.R"))

`%||%` <- function(a, b) if (is.null(a)) b else a

stopifnot(Init()$status_code == 200)
event <- GetEventPayload()
stopifnot(event$status_code == 200)

order_id <- "unknown"
if (!is.null(event$payload) && is.list(event$payload)) {
  order_id <- event$payload$orderId %||% event$payload$id %||% order_id
}

ack_dir <- Sys.getenv("EXAMPLE_ACK_DIR", "/tmp/coreauto-example")
dir.create(ack_dir, recursive = TRUE, showWarnings = FALSE)
ack_path <- file.path(ack_dir, paste0(order_id, ".json"))

order <- list(orderId = order_id, details = event$payload)
text <- JsonStringify(order)
stopifnot(text$status_code == 200)
stopifnot(LocalWrite(ack_path, text$text)$status_code == 200)

out <- list(orderId = order_id, ackPath = ack_path)
stopifnot(PutStepPayload(out)$status_code == 200)

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("install.packages('jsonlite')")
cat(jsonlite::toJSON(list(status_code = 200L, result = out), auto_unbox = TRUE), "\n")
