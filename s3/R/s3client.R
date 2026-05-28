# Copyright Core DF — Apache License 2.0

s3_missing_env <- function(vars) list(status_code = 601L, error = paste("Environment variables", vars, "should be defined"))
s3_transport_error <- function(message = "inaccessible") list(status_code = 0L, error = message)

`%||%` <- function(a, b) if (is.null(a) || (is.character(a) && !nzchar(a))) b else a

.bucket <- function(explicit) {
  b <- explicit %||% Sys.getenv("S3_BUCKET")
  if (!nzchar(b)) return(NULL)
  b
}

.s3_region <- function() {
  r <- Sys.getenv("AWS_REGION")
  if (nzchar(r)) return(r)
  r <- Sys.getenv("AWS_DEFAULT_REGION")
  if (nzchar(r)) return(r)
  "us-east-1"
}

.s3_endpoint <- function() {
  ep <- Sys.getenv("S3_ENDPOINT_URL")
  if (nzchar(ep)) ep else NULL
}

Init <- function() {
  if (!nzchar(Sys.getenv("AWS_ACCESS_KEY_ID")) && !nzchar(Sys.getenv("AWS_PROFILE"))) {
    return(s3_missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE"))
  }
  if (!nzchar(Sys.getenv("S3_BUCKET"))) {
    return(s3_missing_env("S3_BUCKET (or pass bucket per call)"))
  }
  list(status_code = 200L)
}

GetObject <- function(key, bucket_name = NULL) {
  if (!requireNamespace("aws.s3", quietly = TRUE)) stop("install.packages('aws.s3')")
  b <- .bucket(bucket_name)
  if (is.null(b)) return(s3_missing_env("S3_BUCKET"))
  tryCatch({
    endpoint <- .s3_endpoint()
    txt <- aws.s3::s3read_using(
      function(con) paste(readLines(con, warn = FALSE), collapse = "\n"),
      object = key,
      bucket = b,
      region = .s3_region(),
      endpoint = endpoint
    )
    list(status_code = 200L, content = txt)
  }, error = function(e) s3_transport_error(e$message))
}

PutObject <- function(key, content, bucket_name = NULL) {
  if (!requireNamespace("aws.s3", quietly = TRUE)) stop("install.packages('aws.s3')")
  b <- .bucket(bucket_name)
  if (is.null(b)) return(s3_missing_env("S3_BUCKET"))
  tryCatch({
    endpoint <- .s3_endpoint()
    tf <- tempfile()
    on.exit(unlink(tf), add = TRUE)
    writeLines(content, tf, useBytes = FALSE)
    aws.s3::put_object(
      file = tf,
      object = key,
      bucket = b,
      region = .s3_region(),
      endpoint = endpoint
    )
    list(status_code = 200L)
  }, error = function(e) s3_transport_error(e$message))
}

ListObjects <- function(prefix = "", bucket_name = NULL) {
  if (!requireNamespace("aws.s3", quietly = TRUE)) stop("install.packages('aws.s3')")
  b <- .bucket(bucket_name)
  if (is.null(b)) return(s3_missing_env("S3_BUCKET"))
  tryCatch({
    endpoint <- .s3_endpoint()
    df <- aws.s3::get_bucket_df(
      bucket = b,
      prefix = prefix,
      region = .s3_region(),
      endpoint = endpoint,
      max = 1000L
    )
    keys <- if (is.data.frame(df) && "Key" %in% names(df)) as.character(df$Key) else character(0)
    list(status_code = 200L, keys = keys)
  }, error = function(e) s3_transport_error(e$message))
}
