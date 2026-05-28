#!/usr/bin/env ruby
# frozen_string_literal: true
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
# Kafka ingress bridge — Ruby port.

require 'json'

ROOT = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(ROOT, 'queues/kafka/Ruby/lib'))
$LOAD_PATH.unshift(File.join(ROOT, 'queues/ingress/Ruby/lib'))
require_relative '../../queues/ingress/Ruby/ingress'
require 'kafkaclient'

topic = ARGV[0] || ENV.fetch('EXAMPLE_KAFKA_TOPIC', 'orders.inbound')
warn "Bridging Kafka topic #{topic.inspect} → Core Auto (CA_EVENT_NAME)"
loop do
  result = Ingress::RunBridge(-> { Kafkaclient::Consume(topic, max_messages: 10) })
  code = result[:status_code] || 0
  if code >= 400 || code.zero?
    warn JSON.generate(result)
    sleep 5
    next
  end
  puts JSON.generate(forwarded: result[:forwarded]) if result[:forwarded]&.any?
end
