# frozen_string_literal: true
require 'json'
require_relative 'result'
module Kafkaclient
  module_function
  def bootstrap = ENV.fetch('KAFKA_BOOTSTRAP_SERVERS', '')
  def Init
    return CoreautoResult.missing_env('KAFKA_BOOTSTRAP_SERVERS') if bootstrap.empty?
    { status_code: 200 }
  end
  def Produce(topic, value, key: nil)
    return CoreautoResult.missing_env('KAFKA_BOOTSTRAP_SERVERS') if bootstrap.empty?
    begin
      require 'kafka'
    rescue LoadError
      return { status_code: 500, error: 'kafka gem required' }
    end
    payload = value.is_a?(Hash) || value.is_a?(Array) ? JSON.generate(value) : value.to_s
    kafka = Kafka.new(seed_brokers: bootstrap.split(','))
    kafka.deliver_message(payload, topic: topic, key: key)
    { status_code: 200 }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
  def Consume(topic, timeout_sec: 30, max_messages: 1, group_id: nil)
    return CoreautoResult.missing_env('KAFKA_BOOTSTRAP_SERVERS') if bootstrap.empty?
    begin
      require 'kafka'
    rescue LoadError
      return { status_code: 500, error: 'kafka gem required' }
    end
    gid = group_id || ENV.fetch('KAFKA_GROUP_ID', 'coreauto-step')
    kafka = Kafka.new(seed_brokers: bootstrap.split(','))
    consumer = kafka.consumer(group_id: gid)
    consumer.subscribe(topic)
    messages = []
    consumer.each_message(max_wait_time: timeout_sec) do |m|
      body = begin; JSON.parse(m.value); rescue; m.value; end
      messages << { topic: m.topic, partition: m.partition, offset: m.offset, key: m.key, value: body }
      break if messages.size >= max_messages
    end
    consumer.stop
    { status_code: 200, messages: messages }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
