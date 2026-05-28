#!/usr/bin/env bash
# Copyright Core DF — Apache License 2.0
# COBOL example driver — runs Shell full integration step (same scenario).
set -euo pipefail
exec "$(dirname "$0")/../Shell/full_integration_step.sh"
