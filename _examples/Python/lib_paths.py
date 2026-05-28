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

"""Add coreauto-scripts-pub library paths for Examples/Python scripts."""

import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]

_PATHS = (
    "cawbs/Python",
    "http/Python",
    "files/Python",
    "notify/Python",
    "s3/Python",
    "transform/Python",
    "queues/kafka/Python",
    "queues/rabbit/Python",
    "queues/sqs/Python",
    "queues/redis/Python",
    "queues/servicebus/Python",
    "queues/nats/Python",
    "queues/ibmmq/Python",
    "queues/pubsub/Python",
)


def setup() -> Path:
    for rel in _PATHS:
        path = str(_REPO_ROOT / rel)
        if path not in sys.path:
            sys.path.insert(0, path)
    return _REPO_ROOT
