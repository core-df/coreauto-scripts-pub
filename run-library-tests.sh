#!/usr/bin/env bash
# Run Python and Go unit tests for coreauto-scripts-pub libraries.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

# Homebrew libcjson / libcurl (macOS); adjust if your prefix differs.
EXTRA_CFLAGS=()
EXTRA_LDFLAGS=()
if [[ -d /opt/homebrew/include/cjson ]]; then
  EXTRA_CFLAGS+=(-I/opt/homebrew/include/cjson)
  EXTRA_LDFLAGS+=(-L/opt/homebrew/lib)
fi
if [[ -d /opt/homebrew/opt/curl/include ]]; then
  EXTRA_CFLAGS+=(-I/opt/homebrew/opt/curl/include)
  EXTRA_LDFLAGS+=(-L/opt/homebrew/opt/curl/lib)
fi
if [[ -d /opt/homebrew/include/librdkafka ]]; then
  EXTRA_CFLAGS+=(-I/opt/homebrew/include)
  EXTRA_LDFLAGS+=(-L/opt/homebrew/lib -lrdkafka -lz -lpthread)
fi
export EXTRA_CFLAGS="${EXTRA_CFLAGS[*]:-}"
export EXTRA_LDFLAGS="${EXTRA_LDFLAGS[*]:-}"

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

echo "=== C tests ==="
for mod in cawbs/C http/C notify/C files/C s3/C transform/C \
  queues/kafka/C queues/rabbit/C queues/sqs/C queues/redis/C \
  queues/servicebus/C queues/nats/C queues/ibmmq/C queues/pubsub/C queues/ingress/C; do
  echo ">> $mod"
  (cd "$ROOT/$mod" && make test EXTRA_CFLAGS="$EXTRA_CFLAGS" EXTRA_LDFLAGS="$EXTRA_LDFLAGS")
done

echo "All library tests passed."
