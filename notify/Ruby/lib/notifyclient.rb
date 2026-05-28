# frozen_string_literal: true

# Copyright Core DF — Apache License 2.0

require 'json'
require 'net/http'
require 'uri'
require_relative '../../../http/Ruby/lib/result'

module Notifyclient
  module_function

  def Slack(text, webhook_url: nil)
    url = webhook_url || ENV['SLACK_WEBHOOK_URL']
    return CoreautoResult.missing_env('SLACK_WEBHOOK_URL') if url.to_s.empty?

    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(text: text)
    resp = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |h| h.request(req) }
    return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400

    { status_code: 200 }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Teams(text, webhook_url: nil)
    url = webhook_url || ENV['TEAMS_WEBHOOK_URL']
    return CoreautoResult.missing_env('TEAMS_WEBHOOK_URL') if url.to_s.empty?

    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    payload = { '@type' => 'MessageCard', '@context' => 'http://schema.org/extensions', 'text' => text }
    req.body = JSON.generate(payload)
    resp = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') { |h| h.request(req) }
    return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400

    { status_code: 200 }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def PagerDuty(summary, routing_key: nil, severity: 'error')
    key = routing_key || ENV['PAGERDUTY_ROUTING_KEY']
    return CoreautoResult.missing_env('PAGERDUTY_ROUTING_KEY') if key.to_s.empty?

    uri = URI('https://events.pagerduty.com/v2/enqueue')
    req = Net::HTTP::Post.new(uri)
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(
      routing_key: key,
      event_action: 'trigger',
      payload: { summary: summary, severity: severity, source: 'coreauto-step' }
    )
    resp = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
    return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400

    { status_code: 200 }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Email(subject, body, to_addrs, from_addr: nil)
    host = ENV['SMTP_HOST']
    port = (ENV['SMTP_PORT'] || '587').to_i
    user = ENV['SMTP_USER']
    password = ENV['SMTP_PASSWORD']
    sender = from_addr || ENV['SMTP_FROM'] || user
    return CoreautoResult.missing_env('SMTP_HOST and SMTP_FROM (or from_addr)') if host.to_s.empty? || sender.to_s.empty?

    require 'net/smtp'
    msg = <<~MSG
      From: #{sender}
      To: #{to_addrs}
      Subject: #{subject}

      #{body}
    MSG
    Net::SMTP.start(host, port) do |smtp|
      smtp.enable_starttls if smtp.respond_to?(:enable_starttls) && user && password
      smtp.authenticate(user, password) if user && password
      smtp.send_message(msg, sender, to_addrs.split(',').map(&:strip))
    end
    { status_code: 200 }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
