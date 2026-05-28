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
# Core Auto Web Services library (cawbs) — shell client for the Core Auto Collector.
#
# Provides HTTP access to the Core Auto Collector REST API for real-time step scripts.
# Part of the coreauto-scripts-pub repository; not related to coreauto-mngr-pub
# (PostgreSQL-backed agents and workers).
#
# Documentation: https://coreauto.coredf.com/resources
#
# Required environment variables:
#   ENV            - Target environment name (sent as the Environment header).
#   ACTIONID       - Real-time action identifier for the current run.
#   CA_ACCESS_CODE - API access code used to obtain a bearer token.
#   CA_WBS_URL     - Base URL of the Core Auto Collector web service.
#   STEPNAME       - Name of the current step (used by PutStepPayload).
#
# Typical usage:
#   source /path/to/cawbs/Shell/cawbs.sh
#   Init
#   if [[ "$WBS_STATUS_CODE" != "200" ]]; then echo "$WBS_ERROR" >&2; exit 1; fi
#   GetEventPayload
#   PutStepPayload '{"key":"value"}'

_CAWBS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/wbs.sh
source "${_CAWBS_DIR}/lib/wbs.sh"

Init() {
  if [[ -z ${ENV:-} || -z ${ACTIONID:-} || -z ${CA_ACCESS_CODE:-} || -z ${CA_WBS_URL:-} || -z ${STEPNAME:-} ]]; then
    _wbs_set_result 601 "Environment variables ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME should be defined"
    return 0
  fi
  _wbs_authenticate "$ENV" "$CA_ACCESS_CODE" "$CA_WBS_URL"
}

GetEventPayload() {
  _wbs_get_event_payload "$ACTIONID"
}

PutStepPayload() {
  _wbs_put_step_payload "$ACTIONID" "$STEPNAME" "$1"
}

GetStepPayload() {
  _wbs_get_step_payload "$ACTIONID" "$1"
}

GetKeystore() {
  _wbs_get_keystore "$1"
}
