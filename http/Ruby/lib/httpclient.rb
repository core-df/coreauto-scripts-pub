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

require 'json'
require 'net/http'
require 'uri'
require_relative 'result'

module Httpclient
  module_function

  def parse_body(resp)
    return nil if resp.body.nil? || resp.body.empty?

    JSON.parse(resp.body)
  rescue JSON::ParserError
    resp.body
  end

  def request(method, url, headers: nil, body: nil, params: nil)
    uri = URI(url)
    if params && !params.empty?
      q = URI.decode_www_form(uri.query || '') + params.to_a
      uri.query = URI.encode_www_form(q)
    end

    klass = {
      'GET' => Net::HTTP::Get,
      'POST' => Net::HTTP::Post,
      'PUT' => Net::HTTP::Put,
      'DELETE' => Net::HTTP::Delete
    }[method]
    req = klass.new(uri)
    (headers || {}).each { |k, v| req[k] = v }
    req.body = body if body

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 60
    http.read_timeout = 60
    resp = http.request(req)
    code = resp.code.to_i
    parsed = parse_body(resp)
    if code >= 400
      { status_code: code, error: parsed.nil? ? 'inaccessible' : parsed }
    else
      { status_code: code, body: parsed }
    end
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def Get(url, headers: nil, params: nil)
    request('GET', url, headers: headers, params: params)
  end

  def Post(url, json_body: nil, data: nil, headers: nil)
    hdrs = (headers || {}).dup
    body = nil
    if json_body
      hdrs['Content-Type'] ||= 'application/json'
      body = JSON.generate(json_body)
    elsif data
      body = data
    end
    request('POST', url, headers: hdrs, body: body)
  end

  def Put(url, json_body: nil, headers: nil)
    hdrs = (headers || {}).dup
    body = nil
    if json_body
      hdrs['Content-Type'] ||= 'application/json'
      body = JSON.generate(json_body)
    end
    request('PUT', url, headers: hdrs, body: body)
  end

  def Delete(url, headers: nil)
    request('DELETE', url, headers: headers)
  end
end
