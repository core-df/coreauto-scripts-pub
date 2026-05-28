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
# Local file and SFTP helpers for Core Auto step scripts.

_FILECLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_FILECLIENT_DIR}/lib/result.sh"

LocalRead() {
  local path=$1 encoding=${2:-utf-8}
  local content
  if ! content=$(python3 - "$path" "$encoding" <<'PY' 2>&1
import sys
path, encoding = sys.argv[1], sys.argv[2]
try:
    with open(path, "r", encoding=encoding) as fh:
        print(fh.read(), end="")
except OSError as exc:
    print(f"ERROR:{exc}", file=sys.stderr)
    sys.exit(500)
PY
); then
    _file_set_result 500 "$(echo "$content" | sed 's/^ERROR://')"
    return 0
  fi
  _file_set_result 200 "" "$(jq -nc --arg c "$content" '{content: $c}')"
}

LocalWrite() {
  local path=$1 content=$2 encoding=${3:-utf-8}
  local err
  if ! err=$(python3 - "$path" "$encoding" <<'PY' 2>&1
import os, sys
path, encoding = sys.argv[1], sys.argv[2]
content = sys.stdin.read()
try:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding=encoding) as fh:
        fh.write(content)
except OSError as exc:
    print(f"ERROR:{exc}", file=sys.stderr)
    sys.exit(500)
PY
<<< "$content"); then
    _file_set_result 500 "$(echo "$err" | sed 's/^ERROR://')"
    return 0
  fi
  _file_set_result 200
}

LocalMove() {
  local src=$1 dest=$2
  if mv "$src" "$dest" 2>/dev/null; then
    _file_set_result 200
  else
    _file_set_result 500 "move failed: ${src} -> ${dest}"
  fi
}

_file_sftp_batch() {
  local commands=$1
  local host=${SFTP_HOST:-}
  local user=${SFTP_USER:-}
  local port=${SFTP_PORT:-22}
  local key_path=${SFTP_PRIVATE_KEY:-}

  if [[ -z $host || -z $user ]]; then
    _file_missing_env "SFTP_HOST and SFTP_USER"
    return 1
  fi

  local -a sftp_args=(-b - -P "$port")
  if [[ -n $key_path ]]; then
    sftp_args+=(-i "$key_path")
  fi
  sftp_args+=("${user}@${host}")

  local err
  if ! err=$(printf '%s\n' "$commands" | sftp "${sftp_args[@]}" 2>&1); then
    _file_transport_error "$err"
    return 1
  fi
  return 0
}

SftpGet() {
  local remote_path=$1 local_path=$2
  local parent
  parent=$(dirname "$local_path")
  [[ -n $parent && $parent != . ]] && mkdir -p "$parent"
  _file_sftp_batch "get ${remote_path} ${local_path}" || return 0
  _file_set_result 200
}

SftpPut() {
  local local_path=$1 remote_path=$2
  _file_sftp_batch "put ${local_path} ${remote_path}" || return 0
  _file_set_result 200
}

SftpList() {
  local remote_dir=${1:-.}
  local out
  if ! out=$(sftp -b - "${SFTP_USER}@${SFTP_HOST}" <<EOF 2>&1
ls ${remote_dir}
EOF
); then
    _file_transport_error "$out"
    return 0
  fi
  local files
  files=$(echo "$out" | awk '{print $NF}' | jq -R . | jq -s -c '{files: .}')
  _file_set_result 200 "" "$files"
}
