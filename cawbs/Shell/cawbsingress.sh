#!/usr/bin/env bash
# Copyright Core DF

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
# Core Auto Web Services — ingress client for the Core Auto Collector.
#
# Use outside step scripts (queue bridges, schedulers, file watchers) to submit
# events and flags that trigger Core Auto real-time or batch workflows.
#
# Documentation: https://coreauto.coredf.com/resources
#
# Required environment variables:
#   ENV            - Target environment name (sent as the Environment header).
#   CA_ACCESS_CODE - API access code used to obtain a bearer token.
#   CA_WBS_URL     - Base URL of the Core Auto Collector web service.
#
# Typical usage:
#   source /path/to/cawbs/Shell/cawbsingress.sh
#   Init
#   if [[ "$WBS_STATUS_CODE" != "200" ]]; then echo "$WBS_ERROR" >&2; exit 1; fi
#   PostEvent "OrderCreated" '{"orderId":"123"}'

_CAWBSINGRESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/wbs.sh
source "${_CAWBSINGRESS_DIR}/lib/wbs.sh"

Init() {
  if [[ -z ${ENV:-} || -z ${CA_ACCESS_CODE:-} || -z ${CA_WBS_URL:-} ]]; then
    _wbs_set_result 601 "Environment variables ENV, CA_ACCESS_CODE, CA_WBS_URL should be defined"
    return 0
  fi
  _wbs_authenticate "$ENV" "$CA_ACCESS_CODE" "$CA_WBS_URL"
}

PostEvent() {
  _wbs_post_event "$1" "$2" "${3:-}"
}

GetEventStatus() {
  _wbs_get_event_status "$1"
}

GetEventList() {
  _wbs_get_event_list
}

SubmitFlag() {
  _wbs_submit_flag "$1" "$2" "$3" "$4"
}

GetKeystore() {
  _wbs_get_keystore "$1"
}
