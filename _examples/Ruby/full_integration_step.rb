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
# Core Auto real-time step — full integration example (Ruby port).

require 'json'
require 'fileutils'

ROOT = File.expand_path('../..', __dir__)
%w[
  cawbs/Ruby/lib http/Ruby/lib files/Ruby/lib notify/Ruby/lib
  s3/Ruby/lib transform/Ruby/lib
  queues/kafka/Ruby/lib queues/rabbit/Ruby/lib queues/sqs/Ruby/lib
  queues/redis/Ruby/lib queues/servicebus/Ruby/lib queues/nats/Ruby/lib
  queues/ibmmq/Ruby/lib queues/pubsub/Ruby/lib
].each { |rel| $LOAD_PATH.unshift(File.join(ROOT, rel)) }

require 'cawbs'
require 'httpclient'
require 'fileclient'
require 'notifyclient'
require 's3client'
require 'transformclient'
require 'kafkaclient'
require 'rabbitclient'
require 'sqsclient'
require 'redisclient'
require 'servicebusclient'
require 'natsclient'
require 'ibmmqclient'
require 'pubsubclient'

def code_of(result)
  if result.respond_to?(:status_code)
    result.status_code
  else
    result[:status_code] || result['status_code'] || 0
  end
end

def field(result, key)
  if result.respond_to?(key)
    result.public_send(key)
  else
    result[key] || result[key.to_sym]
  end
end

def fail!(result, label)
  err = result.respond_to?(:to_h) ? result.to_h : result
  warn JSON.pretty_generate(step: label, error: err)
  exit 1
end

def ok!(result, label)
  fail!(result, label) if code_of(result) >= 400 || code_of(result).zero?
  result
end

def optional(label)
  result = yield
  code = code_of(result)
  err = field(result, :error).to_s.downcase
  if [601, 500].include?(code) && err.include?('missing')
    puts "[skip] #{label}: not configured"
    return nil
  end
  if code >= 400 || code.zero?
    puts "[warn] #{label}: #{field(result, :error) || result}"
    return nil
  end
  puts "[ok] #{label}"
  result
end

def load_input(event)
  order = (event.payload || {}).transform_keys(&:to_s)
  order_id = order['orderId'] || order['id'] || 'unknown'
  csv_path = order['csvPath'] || ENV.fetch('EXAMPLE_CSV_PATH', '')
  if !csv_path.empty?
    raw = ok!(Fileclient::LocalRead(csv_path), 'files.LocalRead')
    rows = ok!(Transformclient::CsvToRows(raw[:content] || field(raw, :content)), 'transform.CsvToRows')
    order['lineItems'] = rows[:rows] || field(rows, :rows) if (rows[:rows] || field(rows, :rows))&.any?
  end
  { 'orderId' => order_id, 'details' => order }
end

def s3_enrich(order)
  prefix = ENV.fetch('S3_CONFIG_PREFIX', 'config/')
  got = optional('s3.GetObject') { S3client::GetObject("#{prefix}enrichment.json") }
  if got && (got[:content] || field(got, :content))
    cfg = ok!(Transformclient::JsonParse(got[:content] || field(got, :content)), 'transform.JsonParse(config)')
    order['config'] = cfg[:data] || field(cfg, :data)
  end
  body = ok!(Transformclient::JsonStringify(order), 'transform.JsonStringify')
  optional('s3.PutObject') { S3client::PutObject("orders/#{order['orderId']}/enriched.json", body[:text] || field(body, :text)) }
  order
end

def publish_all_queues(order)
  published = []
  topic = ENV.fetch('EXAMPLE_KAFKA_TOPIC', 'orders.enriched')
  queue = ENV.fetch('EXAMPLE_QUEUE_NAME', 'orders')
  subject = ENV.fetch('EXAMPLE_NATS_SUBJECT', 'orders.enriched')
  {
    'kafka' => -> { Kafkaclient::Produce(topic, order) },
    'rabbit' => -> { Rabbitclient::Publish(queue, order) },
    'sqs' => -> { Sqsclient::Send(order) },
    'redis' => -> { Redisclient::Push(queue, order) },
    'servicebus' => -> { Servicebusclient::Send(order) },
    'nats' => -> { Natsclient::Publish(subject, order) },
    'ibmmq' => -> { Ibmmqclient::Put(order, queue: queue) },
    'pubsub' => -> { Pubsubclient::Publish(order) },
  }.each do |name, fn|
    published << name if optional("queues.#{name}") { fn.call }
  end
  published
end

ok!(Cawbs::Init, 'cawbs.Init')
event = ok!(Cawbs::GetEventPayload, 'cawbs.GetEventPayload')
order = load_input(event)
ack_dir = ENV.fetch('EXAMPLE_ACK_DIR', '/tmp/coreauto-example')
FileUtils.mkdir_p(ack_dir)
ack_path = "#{ack_dir}/#{order['orderId']}.json"
ack_text = ok!(Transformclient::JsonStringify(order), 'transform.JsonStringify(ack)')
ok!(Fileclient::LocalWrite(ack_path, ack_text[:text] || field(ack_text, :text)), 'files.LocalWrite')
order = s3_enrich(order)
published = publish_all_queues(order)
output = { orderId: order['orderId'], queuesPublished: published, ackPath: ack_path }
ok!(Cawbs::PutStepPayload(output), 'cawbs.PutStepPayload')
puts JSON.pretty_generate(status_code: 200, result: output)
