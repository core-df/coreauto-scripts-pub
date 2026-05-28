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

module Pubsubclient
  module_function

  def project_id
    ENV['PUBSUB_PROJECT_ID'] || ENV['GOOGLE_CLOUD_PROJECT'].to_s
  end

  def topic_id(explicit = nil)
    explicit && !explicit.empty? ? explicit : ENV['PUBSUB_TOPIC_ID'].to_s
  end

  def subscription_id(explicit = nil)
    explicit && !explicit.empty? ? explicit : ENV['PUBSUB_SUBSCRIPTION_ID'].to_s
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
    return CoreautoResult.missing_env('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT') if project_id.empty?
    { status_code: 200 }
  end

  def Publish(value, topic: nil)
    project = project_id
    tid = topic_id(topic)
    return CoreautoResult.missing_env('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT') if project.empty?
    return CoreautoResult.missing_env('PUBSUB_TOPIC_ID') if tid.empty?
    require 'google/cloud/pubsub'
    pubsub = Google::Cloud::Pubsub.new(project_id: project)
    t = pubsub.topic(tid)
    msg_id = t.publish(encode(value))
    { status_code: 200, message_id: msg_id }
  rescue LoadError
    { status_code: 500, error: 'google-cloud-pubsub gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Pull(subscription: nil, max_messages: 1, timeout_sec: 30, ack: true)
    project = project_id
    sub_id = subscription_id(subscription)
    return CoreautoResult.missing_env('PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT') if project.empty?
    return CoreautoResult.missing_env('PUBSUB_SUBSCRIPTION_ID') if sub_id.empty?
    require 'google/cloud/pubsub'
    pubsub = Google::Cloud::Pubsub.new(project_id: project)
    sub = pubsub.subscription(sub_id)
    received = sub.pull(immediate: false, max: [max_messages, 1].max)
    messages = received.map { |msg| { subscription: sub_id, message_id: msg.message_id, value: decode(msg.data) } }
    sub.acknowledge(received) if ack && !received.empty?
    { status_code: 200, messages: messages }
  rescue LoadError
    { status_code: 500, error: 'google-cloud-pubsub gem required' }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
