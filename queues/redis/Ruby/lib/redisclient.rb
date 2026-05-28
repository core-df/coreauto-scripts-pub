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

module Redisclient
  module_function

  def connection_url
    return ENV['REDIS_URL'] if ENV['REDIS_URL'] && !ENV['REDIS_URL'].empty?
    host = ENV['REDIS_HOST'].to_s
    return '' if host.empty?
    port = ENV.fetch('REDIS_PORT', '6379')
    db = ENV.fetch('REDIS_DB', '0')
    pass = ENV['REDIS_PASSWORD'].to_s
    pass.empty? ? "redis://\#{host}:\#{port}/\#{db}" : "redis://:\#{pass}@\#{host}:\#{port}/\#{db}"
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
    return CoreautoResult.missing_env('REDIS_URL or REDIS_HOST') if connection_url.empty?
    { status_code: 200 }
  end

  def Push(queue, value)
    return CoreautoResult.missing_env('REDIS_URL or REDIS_HOST') if connection_url.empty?
    require 'redis'
    Redis.new(url: connection_url).lpush(queue, encode(value))
    { status_code: 200 }
  rescue LoadError
    { status_code: 500, error: 'redis gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Pop(queue, timeout_sec: 30, max_messages: 1)
    return CoreautoResult.missing_env('REDIS_URL or REDIS_HOST') if connection_url.empty?
    require 'redis'
    r = Redis.new(url: connection_url)
    messages = []
    remaining = [max_messages, 1].max
    while remaining > 0
      wait = remaining == max_messages ? [timeout_sec.to_i, 1].max : 1
      item = r.brpop(queue, timeout: wait)
      break unless item
      _key, body = item
      messages << { queue: queue, value: decode(body) }
      remaining -= 1
      timeout_sec -= wait
      break if timeout_sec <= 0
    end
    { status_code: 200, messages: messages }
  rescue LoadError
    { status_code: 500, error: 'redis gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
