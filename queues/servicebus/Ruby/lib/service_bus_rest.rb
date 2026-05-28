# Copyright Core DF — Apache License 2.0
# Azure Service Bus REST helpers (SharedAccessSignature).

require 'json'
require 'net/http'
require 'uri'
require 'cgi'
require 'base64'
require 'openssl'

module ServiceBusRest
  module_function

  def parse_conn_string(conn)
    parts = conn.split(';').map { |p| p.split('=', 2) }.to_h
    endpoint = parts['Endpoint'].to_s.sub(%r{^sb://}, 'https://').delete_suffix('/')
    {
      endpoint: endpoint,
      key_name: parts['SharedAccessKeyName'],
      key: parts['SharedAccessKey'],
    }
  end

  def sas_token(resource_uri, key_name, key)
    expiry = (Time.now.to_i + 3600).to_s
    encoded = CGI.escape(resource_uri)
    string_to_sign = "#{encoded}\n#{expiry}"
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest('sha256', key, string_to_sign))
    "SharedAccessSignature sr=#{encoded}&sig=#{CGI.escape(signature)}&se=#{expiry}&skn=#{CGI.escape(key_name)}"
  end

  def send_message(conn, queue, body)
    cfg = parse_conn_string(conn)
    resource = "#{cfg[:endpoint]}/#{queue}"
    url = URI("#{resource}/messages")
    req = Net::HTTP::Post.new(url)
    req['Authorization'] = sas_token(resource, cfg[:key_name], cfg[:key])
    req['Content-Type'] = 'application/json'
    req.body = body.is_a?(String) ? body : JSON.generate(body)
    resp = Net::HTTP.start(url.host, url.port, use_ssl: true) { |h| h.request(req) }
    return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400
    { status_code: 200 }
  end

  def receive_messages(conn, queue, timeout_sec, max_messages, complete)
    cfg = parse_conn_string(conn)
    resource = "#{cfg[:endpoint]}/#{queue}"
    messages = []
    max_messages.times do
      url = URI("#{resource}/messages/head?timeout=#{timeout_sec.to_i}")
      req = Net::HTTP::Post.new(url)
      req['Authorization'] = sas_token(resource, cfg[:key_name], cfg[:key])
      resp = Net::HTTP.start(url.host, url.port, use_ssl: true) { |h| h.request(req) }
      break if resp.code.to_i == 204 || resp.body.to_s.empty?
      return { status_code: resp.code.to_i, error: resp.body } if resp.code.to_i >= 400
      lock = resp['BrokerProperties'] && JSON.parse(resp['BrokerProperties'])['LockToken'] rescue nil
      value = begin; JSON.parse(resp.body); rescue; resp.body; end
      messages << { queue: queue, message_id: resp['BrokerProperties'], value: value }
      if complete && lock
        del = URI("#{resource}/messages/#{lock}")
        del_req = Net::HTTP::Delete.new(del)
        del_req['Authorization'] = sas_token(resource, cfg[:key_name], cfg[:key])
        Net::HTTP.start(del.host, del.port, use_ssl: true) { |h| h.request(del_req) }
      end
    end
    { status_code: 200, messages: messages }
  end
end
