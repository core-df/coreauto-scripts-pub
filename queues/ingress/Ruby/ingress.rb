# frozen_string_literal: true

# Copyright Core DF — Apache License 2.0
#
# Queue ingress bridge — consume from a queue and submit Core Auto events via cawbsingress.

require_relative '../../../cawbs/Ruby/lib/cawbsingress'
require_relative 'lib/result'

module Ingress
  module_function

  def TriggerEvent(payload, event_name: nil, event_source: nil)
    name = event_name || ENV['CA_EVENT_NAME']
    return CoreautoResult.missing_env('CA_EVENT_NAME (or pass event_name)') if name.to_s.empty?

    source = !event_source.nil? ? event_source : ENV['CA_EVENT_SOURCE']
    init = Cawbsingress.Init
    return init if init[:status_code].to_i >= 400

    kwargs = { event_name: name, payload: payload }
    kwargs[:event_source] = source if source && !source.empty?
    Cawbsingress.PostEvent(kwargs[:event_name], kwargs[:payload], event_source: kwargs[:event_source])
  end

  def ForwardMessages(consume_result)
    return consume_result if consume_result[:status_code].to_i != 200

    forwarded = []
    (consume_result[:messages] || []).each do |msg|
      value = msg.key?(:value) ? msg[:value] : msg
      result = TriggerEvent(value)
      return result if result[:status_code].to_i >= 400
      forwarded << { actionId: result[:actionId], eventId: result[:eventId] }
    end
    { status_code: 200, forwarded: forwarded }
  end

  def RunBridge(consume_fn, **consume_kwargs)
    ForwardMessages(consume_fn.call(**consume_kwargs))
  end
end
