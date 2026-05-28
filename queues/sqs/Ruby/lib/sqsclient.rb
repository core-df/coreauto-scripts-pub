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

module Sqsclient
  module_function

  def queue_url(explicit = nil)
    explicit && !explicit.empty? ? explicit : ENV['SQS_QUEUE_URL'].to_s
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

  def client
    require 'aws-sdk-sqs'
    region = ENV['AWS_REGION'] || ENV['AWS_DEFAULT_REGION'] || 'us-east-1'
    opts = { region: region }
    opts[:endpoint] = ENV['SQS_ENDPOINT_URL'] if ENV['SQS_ENDPOINT_URL'] && !ENV['SQS_ENDPOINT_URL'].empty?
    Aws::SQS::Client.new(opts)
  end

  def Init
    return CoreautoResult.missing_env('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE') if ENV['AWS_ACCESS_KEY_ID'].to_s.empty? && ENV['AWS_PROFILE'].to_s.empty?
    return CoreautoResult.missing_env('SQS_QUEUE_URL (or pass queue_url per call)') if ENV['SQS_QUEUE_URL'].to_s.empty?
    { status_code: 200 }
  end

  def Send(value, queue_url: nil)
    url = self.queue_url(queue_url)
    return CoreautoResult.missing_env('SQS_QUEUE_URL') if url.empty?
    resp = client.send_message(queue_url: url, message_body: encode(value))
    { status_code: 200, message_id: resp.message_id }
  rescue LoadError
    { status_code: 500, error: 'aws-sdk-sqs gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Receive(queue_url: nil, max_messages: 1, wait_time_sec: 10, delete: true)
    url = self.queue_url(queue_url)
    return CoreautoResult.missing_env('SQS_QUEUE_URL') if url.empty?
    max_messages = [[max_messages, 1].max, 10].min
    resp = client.receive_message(queue_url: url, max_number_of_messages: max_messages, wait_time_seconds: wait_time_sec)
    messages = (resp.messages || []).map do |item|
      h = { message_id: item.message_id, receipt_handle: item.receipt_handle, value: decode(item.body.to_s) }
      client.delete_message(queue_url: url, receipt_handle: item.receipt_handle) if delete && item.receipt_handle
      h
    end
    { status_code: 200, messages: messages }
  rescue LoadError
    { status_code: 500, error: 'aws-sdk-sqs gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
