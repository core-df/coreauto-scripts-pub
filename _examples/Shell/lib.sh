#!/usr/bin/env bash
# Copyright Core DF — Apache License 2.0
EX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$EX_ROOT/cawbs/Shell/cawbs.sh"
source "$EX_ROOT/transform/Shell/transformclient.sh"
source "$EX_ROOT/files/Shell/fileclient.sh"
source "$EX_ROOT/queues/kafka/Shell/kafkaclient.sh"
