#!/usr/bin/env bash
# Run Python and Go unit tests for coreauto-scripts-pub libraries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Go tests ==="
for mod in \
  transform/Go http/Go files/Go s3/Go \
  queues/kafka/Go queues/sqs/Go queues/rabbit/Go queues/redis/Go \
  queues/nats/Go queues/pubsub/Go queues/servicebus/Go queues/ibmmq/Go queues/ingress/Go; do
  echo ">> $mod"
  (cd "$ROOT/$mod" && go test ./... -count=1)
done

echo "=== Python tests ==="
VENV="$ROOT/.test-venv"
if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q pytest requests boto3
fi
for pkg in \
  transform/Python http/Python files/Python s3/Python \
  queues/kafka/Python queues/sqs/Python queues/rabbit/Python queues/redis/Python \
  queues/nats/Python queues/pubsub/Python queues/servicebus/Python queues/ibmmq/Python \
  queues/ingress/Python; do
  echo ">> $pkg"
  (cd "$ROOT/$pkg" && PYTHONPATH=. "$VENV/bin/python" -m pytest tests/ -q)
done

echo "All library tests passed."
