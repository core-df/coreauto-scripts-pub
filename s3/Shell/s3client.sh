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
# S3-compatible object storage helpers (AWS S3, MinIO, etc.).

_S3CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_S3CLIENT_DIR}/lib/result.sh"

Init() {
  if [[ -z ${AWS_ACCESS_KEY_ID:-} && -z ${AWS_PROFILE:-} ]]; then
    _s3_missing_env "AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE"
    return 0
  fi
  if [[ -z ${S3_BUCKET:-} ]]; then
    _s3_missing_env "S3_BUCKET (or pass bucket per call)"
    return 0
  fi
  if ! command -v aws >/dev/null 2>&1; then
    _s3_set_result 500 "aws CLI required"
    return 0
  fi
  _s3_set_result 200
}

GetObject() {
  local key=$1 bucket=$(_s3_bucket "${2:-}")
  if [[ -z $bucket ]]; then
    _s3_missing_env "S3_BUCKET"
    return 0
  fi
  if ! command -v aws >/dev/null 2>&1; then
    _s3_set_result 500 "aws CLI required"
    return 0
  fi
  local content err
  # shellcheck disable=SC2046
  if ! content=$(aws s3 cp "s3://${bucket}/${key}" - $( _s3_endpoint_args ) 2>&1); then
    _s3_transport_error "$content"
    return 0
  fi
  _s3_set_result 200 "" "$(jq -nc --arg c "$content" '{content: $c}')"
}

PutObject() {
  local key=$1 content=$2 bucket=$(_s3_bucket "${3:-}")
  if [[ -z $bucket ]]; then
    _s3_missing_env "S3_BUCKET"
    return 0
  fi
  if ! command -v aws >/dev/null 2>&1; then
    _s3_set_result 500 "aws CLI required"
    return 0
  fi
  local err tmp
  tmp=$(mktemp)
  printf '%s' "$content" > "$tmp"
  # shellcheck disable=SC2046
  if ! err=$(aws s3 cp "$tmp" "s3://${bucket}/${key}" $( _s3_endpoint_args ) 2>&1); then
    rm -f "$tmp"
    _s3_transport_error "$err"
    return 0
  fi
  rm -f "$tmp"
  _s3_set_result 200
}

ListObjects() {
  local prefix=${1:-} bucket=$(_s3_bucket "${2:-}")
  if [[ -z $bucket ]]; then
    _s3_missing_env "S3_BUCKET"
    return 0
  fi
  if ! command -v aws >/dev/null 2>&1; then
    _s3_set_result 500 "aws CLI required"
    return 0
  fi
  local out err path="s3://${bucket}/"
  [[ -n $prefix ]] && path="${path}${prefix}"
  # shellcheck disable=SC2046
  if ! out=$(aws s3 ls "$path" $( _s3_endpoint_args ) 2>&1); then
    _s3_transport_error "$out"
    return 0
  fi
  local keys
  keys=$(echo "$out" | awk '{print $NF}' | jq -R . | jq -s -c '{keys: .}')
  _s3_set_result 200 "" "$keys"
}
