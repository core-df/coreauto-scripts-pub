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
require 'uri'
require_relative 'result'

module Rabbitclient
  module_function

  def connection_url
    return ENV['RABBITMQ_URL'] if ENV['RABBITMQ_URL'] && !ENV['RABBITMQ_URL'].empty?
    host = ENV['RABBITMQ_HOST'].to_s
    return '' if host.empty?
    user = URI.encode_www_form_component(ENV.fetch('RABBITMQ_USER', 'guest'))
    pass = URI.encode_www_form_component(ENV.fetch('RABBITMQ_PASSWORD', 'guest'))
    port = ENV.fetch('RABBITMQ_PORT', '5672')
    vhost = URI.encode_www_form_component(ENV.fetch('RABBITMQ_VHOST', '/'))
    "amqp://\#{user}:\#{pass}@\#{host}:\#{port}/\#{vhost}"
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
    return CoreautoResult.missing_env('RABBITMQ_URL or RABBITMQ_HOST') if connection_url.empty?
    { status_code: 200 }
  end

  def Publish(queue, value, durable: true)
    url = connection_url
    return CoreautoResult.missing_env('RABBITMQ_URL or RABBITMQ_HOST') if url.empty?
    require 'bunny'
    conn = Bunny.new(url)
    conn.start
    ch = conn.create_channel
    ch.queue_declare(queue, durable: durable)
    ch.default_exchange.publish(encode(value), routing_key: queue)
    conn.close
    { status_code: 200 }
  rescue LoadError
    { status_code: 500, error: 'bunny gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Consume(queue, timeout_sec: 30, max_messages: 1, auto_ack: true, durable: true)
    url = connection_url
    return CoreautoResult.missing_env('RABBITMQ_URL or RABBITMQ_HOST') if url.empty?
    require 'bunny'
    conn = Bunny.new(url)
    conn.start
    ch = conn.create_channel
    ch.queue_declare(queue, durable: durable)
    messages = []
    deadline = timeout_sec
    while messages.size < max_messages && deadline > 0
      _delivery_info, _props, body = ch.basic_get(queue, manual_ack: !auto_ack)
      if body.nil?
        sleep 1
        deadline -= 1
        next
      end
      messages << { queue: queue, value: decode(body) }
      ch.basic_ack(_delivery_info.delivery_tag) if auto_ack && _delivery_info
      break if messages.size >= max_messages
    end
    conn.close
    { status_code: 200, messages: messages }
  rescue LoadError
    { status_code: 500, error: 'bunny gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
