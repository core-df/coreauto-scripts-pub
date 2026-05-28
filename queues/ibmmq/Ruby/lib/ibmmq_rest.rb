# Copyright Core DF — Apache License 2.0
# IBM MQ REST API helpers (MQ 9.1+ with REST enabled).

require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'openssl'

module IbmmqRest
  module_function

  def base_url
    explicit = ENV['MQ_REST_BASE_URL']
    return explicit.chomp('/') if explicit && !explicit.empty?

    host = ENV['MQ_HOST']
    port = ENV['MQ_REST_PORT'] || '9443'
    "https://#{host}:#{port}/ibmmq/rest/v2"
  end

  def auth_header
    user = ENV['MQ_USER']
    password = ENV['MQ_PASSWORD']
    return {} if user.to_s.empty?
    token = Base64.strict_encode64("#{user}:#{password}")
    { 'Authorization' => "Basic #{token}" }
  end

  def put_message(queue, body)
    qmgr = ENV['MQ_QUEUE_MANAGER']
    url = URI("#{base_url}/messaging/qmgr/#{qmgr}/queue/#{queue}/message")
    req = Net::HTTP::Post.new(url)
    auth_header.each { |k, v| req[k] = v }
    req['Content-Type'] = 'application/json'
    req.body = JSON.generate(type: 'string', content: body.is_a?(String) ? body : JSON.generate(body))
    resp = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |h|
      h.request(req)
    end
    return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400
    { status_code: 200 }
  end

  def get_messages(queue, max_messages)
    qmgr = ENV['MQ_QUEUE_MANAGER']
    messages = []
    max_messages.times do
      url = URI("#{base_url}/messaging/qmgr/#{qmgr}/queue/#{queue}/message")
      req = Net::HTTP::Delete.new(url)
      auth_header.each { |k, v| req[k] = v }
      resp = Net::HTTP.start(url.host, url.port, use_ssl: url.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |h|
        h.request(req)
      end
      break if resp.code.to_i == 204 || resp.body.to_s.empty?
      return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400
      parsed = begin; JSON.parse(resp.body); rescue; resp.body; end
      value = parsed.is_a?(Hash) ? (parsed['content'] || parsed) : parsed
      value = begin; JSON.parse(value); rescue; value; end if value.is_a?(String)
      messages << { queue: queue, value: value }
    end
    { status_code: 200, messages: messages }
  end
end
