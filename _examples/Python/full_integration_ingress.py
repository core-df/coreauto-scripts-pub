#!/usr/bin/env python3
"""
Copyright Core DF

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Long-running ingress bridge — Kafka → Core Auto event.

Uses: kafkaclient.Consume, queues/ingress, cawbsingress.PostEvent

Run as a systemd service or container — NOT as a Core Auto step.
"""

import json
import os
import sys
import time
from pathlib import Path

import lib_paths

lib_paths.setup()

_ingress = Path(__file__).resolve().parents[2] / "queues" / "ingress" / "Python"
if str(_ingress) not in sys.path:
    sys.path.insert(0, str(_ingress))

import ingress
import kafkaclient as kafka


def main() -> None:
    topic = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "EXAMPLE_KAFKA_TOPIC", "orders.inbound"
    )
    print(f"Bridging Kafka topic {topic!r} → Core Auto (CA_EVENT_NAME)", flush=True)

    while True:
        result = ingress.RunBridge(
            kafka.Consume,
            topic=topic,
            timeout_sec=30,
            max_messages=10,
        )
        code = result.get("status_code", 0)
        if code >= 400 or code == 0:
            print(json.dumps(result), file=sys.stderr)
            time.sleep(5)
            continue
        if result.get("forwarded"):
            print(json.dumps({"forwarded": result["forwarded"]}), flush=True)


if __name__ == "__main__":
    main()
