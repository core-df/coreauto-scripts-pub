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

require 'json'
require_relative 'result'

module Natsclient
  module_function

  def servers
    ENV['NATS_URL'] || ENV['NATS_SERVERS'].to_s
  end

  def encode(value)
    return value if value.is_a?(String)
    return JSON.generate(value) if value.is_a?(Hash) || value.is_a?(Array)
    value.to_s
  end

  def decode(raw)
    JSON.parse(raw)
  rescue StandardError
    raw.to_s
  end

  def Init
    return CoreautoResult.missing_env('NATS_URL or NATS_SERVERS') if servers.empty?
    { status_code: 200 }
  end

  def Publish(subject, value)
    return CoreautoResult.missing_env('NATS_URL or NATS_SERVERS') if servers.empty?
    require 'nats-pure'
    NATS.start(servers: servers.split(','))
    NATS.publish(subject, encode(value))
    NATS.stop
    { status_code: 200 }
  rescue LoadError
    { status_code: 500, error: 'nats-pure gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Subscribe(subject, timeout_sec: 30, max_messages: 1)
    return CoreautoResult.missing_env('NATS_URL or NATS_SERVERS') if servers.empty?
    require 'nats-pure'
    messages = []
    NATS.start(servers: servers.split(','))
    sub = NATS.subscribe(subject) { |msg| messages << { subject: subject, value: decode(msg.data) } }
    deadline = timeout_sec
    while messages.size < max_messages && deadline > 0
      NATS.wait(1)
      deadline -= 1
    end
    NATS.unsubscribe(sub)
    NATS.stop
    { status_code: 200, messages: messages.first(max_messages) }
  rescue LoadError
    { status_code: 500, error: 'nats-pure gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
