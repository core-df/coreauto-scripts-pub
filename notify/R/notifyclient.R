# Copyright Core DF — Apache License 2.0

notify_missing_env <- function(vars) list(status_code = 601L, error = paste("Environment variables", vars, "should be defined"))
notify_transport_error <- function(message = "inaccessible") list(status_code = 0L, error = message)

`%||%` <- function(a, b) if (is.null(a) || (is.character(a) && !nzchar(a))) b else a

.post_json <- function(url, payload) {
  if (!requireNamespace("httr", quietly = TRUE)) stop("install.packages('httr')")
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("install.packages('jsonlite')")
  resp <- tryCatch(
    httr::POST(
      url,
      httr::add_headers(`Content-Type` = "application/json"),
      body = jsonlite::toJSON(payload, auto_unbox = TRUE),
      encode = "raw"
    ),
    error = function(e) NULL
  )
  if (is.null(resp)) return(notify_transport_error())
  code <- as.integer(httr::status_code(resp))
  text <- httr::content(resp, as = "text", encoding = "UTF-8")
  if (code >= 400L) return(list(status_code = code, error = text))
  if (!nzchar(text)) return(list(status_code = 200L))
  body <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) text)
  list(status_code = 200L, body = body)
}

Slack <- function(text, webhook_url = NULL) {
  url <- webhook_url %||% Sys.getenv("SLACK_WEBHOOK_URL")
  if (!nzchar(url)) return(notify_missing_env("SLACK_WEBHOOK_URL"))
  .post_json(url, list(text = text))
}

Teams <- function(text, webhook_url = NULL) {
  url <- webhook_url %||% Sys.getenv("TEAMS_WEBHOOK_URL")
  if (!nzchar(url)) return(notify_missing_env("TEAMS_WEBHOOK_URL"))
  .post_json(url, list(
    "@type" = "MessageCard",
    "@context" = "http://schema.org/extensions",
    text = text
  ))
}

PagerDuty <- function(summary, routing_key = NULL, severity = "error") {
  key <- routing_key %||% Sys.getenv("PAGERDUTY_ROUTING_KEY")
  if (!nzchar(key)) return(notify_missing_env("PAGERDUTY_ROUTING_KEY"))
  .post_json("https://events.pagerduty.com/v2/enqueue", list(
    routing_key = key,
    event_action = "trigger",
    payload = list(summary = summary, severity = severity, source = "coreauto-step")
  ))
}

Email <- function(subject, body, to_addrs, from_addr = NULL) {
  host <- Sys.getenv("SMTP_HOST")
  port <- as.integer(Sys.getenv("SMTP_PORT", "587"))
  user <- Sys.getenv("SMTP_USER")
  password <- Sys.getenv("SMTP_PASSWORD")
  sender <- from_addr %||% Sys.getenv("SMTP_FROM") %||% user
  if (!nzchar(host) || !nzchar(sender)) return(notify_missing_env("SMTP_HOST and SMTP_FROM (or from_addr)"))
  tryCatch({
    if (!requireNamespace("emayili", quietly = TRUE)) stop("install.packages('emayili')")
    smtp <- emayili::server(host = host, port = port, username = user, password = password, tls = nzchar(user))
    msg <- emayili::envelope(from = sender, to = to_addrs, subject = subject) %>% emayili::text(body)
    emayili::smtp_send(msg, smtp)
    list(status_code = 200L)
  }, error = function(e) notify_transport_error(e$message))
}
