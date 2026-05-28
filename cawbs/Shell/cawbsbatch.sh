#!/usr/bin/env bash
# Copyright (c) Core DF. All rights reserved.
#
# Core Auto Web Services library (cawbs) — shell client for the Core Auto Collector.
#
# Batch-oriented variant of cawbs for scripts that only need authentication and
# keystore access (no real-time event or step payload APIs). Part of the
# coreauto-scripts-pub repository; not related to coreauto-mngr-pub
# (PostgreSQL-backed agents and workers).
#
# Documentation: https://coreauto.coredf.com/resources
#
# Required environment variables:
#   ENV            - Target environment name (sent as the Environment header).
#   CA_ACCESS_CODE - API access code used to obtain a bearer token.
#   CA_WBS_URL     - Base URL of the Core Auto Collector web service.
#
# Typical usage:
#   source /path/to/cawbs/Shell/cawbsbatch.sh
#   Init
#   if [[ "$WBS_STATUS_CODE" != "200" ]]; then echo "$WBS_ERROR" >&2; exit 1; fi
#   GetKeystore "db_user,db_password"

_CAWBSBATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/wbs.sh
source "${_CAWBSBATCH_DIR}/lib/wbs.sh"

Init() {
  if [[ -z ${ENV:-} || -z ${CA_ACCESS_CODE:-} || -z ${CA_WBS_URL:-} ]]; then
    _wbs_set_result 601 "Environment variables ENV, CA_ACCESS_CODE, CA_WBS_URL should be defined"
    return 0
  fi
  _wbs_authenticate "$ENV" "$CA_ACCESS_CODE" "$CA_WBS_URL"
}

GetKeystore() {
  _wbs_get_keystore "$1"
}
