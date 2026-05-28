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
require_relative 'ibmmq_rest'

module Ibmmqclient
  module_function

  def queue_name(explicit = nil)
    explicit && !explicit.empty? ? explicit : ENV['MQ_QUEUE'].to_s
  end

  def encode(value)
    return value if value.is_a?(String)
    return JSON.generate(value) if value.is_a?(Hash) || value.is_a?(Array)
    value.to_s
  end

  def Init
    return CoreautoResult.missing_env('MQ_HOST and MQ_QUEUE_MANAGER') if ENV['MQ_HOST'].to_s.empty? || ENV['MQ_QUEUE_MANAGER'].to_s.empty?
    return CoreautoResult.missing_env('MQ_QUEUE (or pass queue per call)') if ENV['MQ_QUEUE'].to_s.empty?
    { status_code: 200 }
  end

  def Put(value, queue: nil)
    q = queue_name(queue)
    return CoreautoResult.missing_env('MQ_QUEUE') if q.empty?
    IbmmqRest.put_message(q, encode(value))
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Get(queue: nil, timeout_sec: 30, max_messages: 1)
    q = queue_name(queue)
    return CoreautoResult.missing_env('MQ_QUEUE') if q.empty?
    IbmmqRest.get_messages(q, max_messages)
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
