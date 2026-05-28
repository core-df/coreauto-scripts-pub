#!/usr/bin/env bash
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
# Notification helpers: Slack, Microsoft Teams, email, PagerDuty.

_NOTIFYCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_NOTIFYCLIENT_DIR}/lib/result.sh"

_notify_curl_post() {
  local url=$1 payload=$2
  local raw http_code body
  if ! raw=$(curl -s -S -w $'\n%{http_code}' -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$url"); then
    _notify_transport_error
    return 1
  fi
  http_code=${raw##*$'\n'}
  body=${raw%$'\n'*}
  _NOTIFY_HTTP_CODE=$http_code
  _NOTIFY_BODY=$body
  return 0
}

Slack() {
  local text=$1 webhook_url=${2:-${SLACK_WEBHOOK_URL:-}}
  if [[ -z $webhook_url ]]; then
    _notify_missing_env "SLACK_WEBHOOK_URL"
    return 0
  fi
  local payload
  payload=$(jq -nc --arg t "$text" '{text: $t}')
  _notify_curl_post "$webhook_url" "$payload" || return 0
  if [[ $_NOTIFY_HTTP_CODE -ge 400 ]]; then
    _notify_set_result "$_NOTIFY_HTTP_CODE" "$_NOTIFY_BODY"
  else
    _notify_set_result 200
  fi
}

Teams() {
  local text=$1 webhook_url=${2:-${TEAMS_WEBHOOK_URL:-}}
  if [[ -z $webhook_url ]]; then
    _notify_missing_env "TEAMS_WEBHOOK_URL"
    return 0
  fi
  local payload
  payload=$(jq -nc \
    --arg t "$text" \
    '{"@type":"MessageCard","@context":"http://schema.org/extensions","text":$t}')
  _notify_curl_post "$webhook_url" "$payload" || return 0
  if [[ $_NOTIFY_HTTP_CODE -ge 400 ]]; then
    _notify_set_result "$_NOTIFY_HTTP_CODE" "$_NOTIFY_BODY"
  else
    _notify_set_result 200
  fi
}

Email() {
  local subject=$1 body=$2 to_addrs=$3 from_addr=${4:-${SMTP_FROM:-${SMTP_USER:-}}}
  local host=${SMTP_HOST:-} port=${SMTP_PORT:-587}
  local user=${SMTP_USER:-} password=${SMTP_PASSWORD:-}

  if [[ -z $host || -z $from_addr ]]; then
    _notify_missing_env "SMTP_HOST and SMTP_FROM (or from_addr)"
    return 0
  fi

  local err
  if ! err=$(python3 - "$host" "$port" "$user" "$password" "$from_addr" "$to_addrs" "$subject" <<'PY' 2>&1
import smtplib, sys
from email.mime.text import MIMEText

host, port, user, password = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
sender, to_addrs, subject = sys.argv[5], sys.argv[6], sys.argv[7]
body = sys.stdin.read()
msg = MIMEText(body)
msg["Subject"] = subject
msg["From"] = sender
msg["To"] = to_addrs
try:
    with smtplib.SMTP(host, port, timeout=60) as smtp:
        if user and password:
            smtp.starttls()
            smtp.login(user, password)
        smtp.sendmail(sender, [a.strip() for a in to_addrs.split(",")], msg.as_string())
except smtplib.SMTPException as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)
PY
<<< "$body"); then
    _notify_transport_error "$err"
    return 0
  fi
  _notify_set_result 200
}

PagerDuty() {
  local summary=$1 routing_key=${2:-${PAGERDUTY_ROUTING_KEY:-}} severity=${3:-error}
  if [[ -z $routing_key ]]; then
    _notify_missing_env "PAGERDUTY_ROUTING_KEY"
    return 0
  fi
  local payload
  payload=$(jq -nc \
    --arg rk "$routing_key" \
    --arg s "$summary" \
    --arg sev "$severity" \
    '{routing_key:$rk,event_action:"trigger",payload:{summary:$s,severity:$sev,source:"coreauto-step"}}')
  _notify_curl_post "https://events.pagerduty.com/v2/enqueue" "$payload" || return 0
  if [[ $_NOTIFY_HTTP_CODE -ge 400 ]]; then
    _notify_set_result "$_NOTIFY_HTTP_CODE" "$_NOTIFY_BODY"
  else
    if echo "$_NOTIFY_BODY" | jq -e . >/dev/null 2>&1; then
      _notify_set_result 200 "" "$(echo "$_NOTIFY_BODY" | jq -c '{body: .}')"
    else
      _notify_set_result 200
    fi
  fi
}
