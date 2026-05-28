# frozen_string_literal: true

# Copyright Core DF

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
# Shared HTTP helpers for the Core Auto Collector (cawbs) Ruby client.

require 'json'
require 'net/http'
require 'uri'

module Wbs
  Result = Struct.new(:status_code, :error, :payload, :answer, keyword_init: true) do
    def to_h
      h = { status_code: status_code }
      h[:error] = error unless error.nil?
      h[:payload] = payload unless payload.nil?
      h[:answer] = answer unless answer.nil?
      h
    end
  end

  module_function

  def missing_env(vars)
    Result.new(status_code: 601, error: "Environment variables #{vars} should be defined")
  end

  def trim_url(url)
    url.gsub(/\A[\/ ]+|[\/ ]+\z/, '')
  end

  def do_request(method, url, headers, body = nil)
    uri = URI(url)
    klass = method == :get ? Net::HTTP::Get : Net::HTTP::Post
    req = klass.new(uri)
    headers.each { |k, v| req[k] = v }
    req.body = body if body

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 60
    http.read_timeout = 60

    resp = http.request(req)
    parsed = nil
    if resp.body && !resp.body.empty?
      begin
        parsed = JSON.parse(resp.body)
      rescue JSON::ParserError
        parsed = nil
      end
    end
    [resp.code.to_i, parsed]
  rescue StandardError
    [0, nil]
  end

  def api_error(status_code, body)
    return Result.new(status_code: status_code, error: 'inaccessible') if body.nil?

    Result.new(status_code: status_code, error: body)
  end

  class Session
    attr_reader :initialized

    def initialize
      @initialized = false
      @base_url = ''
      @headers = {}
    end

    def authenticate(env, access_code, base_url)
      return Result.new(status_code: 602, error: 'init already called') if @initialized

      @base_url = Wbs.trim_url(base_url)
      headers = {
        'Content-Type' => 'application/json',
        'Environment' => env
      }
      status_code, body = Wbs.do_request(
        :post,
        "#{@base_url}/v1/auth/apicode",
        headers,
        JSON.generate(apiCode: access_code)
      )
      return Result.new(status_code: status_code, error: 'inaccessible') if status_code.zero?
      return Wbs.api_error(status_code, body) if status_code >= 400
      return Result.new(status_code: status_code, error: 'inaccessible') unless body.is_a?(Hash) && body['token']

      @headers = headers.merge('Authorization' => "Bearer #{body['token']}")
      @initialized = true
      Result.new(status_code: status_code)
    end

    def get_event_payload(action_id)
      return Result.new(status_code: 603, error: 'Init required') unless @initialized

      status_code, body = Wbs.do_request(:get, "#{@base_url}/v1/rtevent/#{action_id}", @headers)
      return Result.new(status_code: status_code, error: 'inaccessible') if status_code.zero?
      return Wbs.api_error(status_code, body) if status_code >= 400
      return Result.new(status_code: status_code, error: 'inaccessible') if body.nil?

      Result.new(status_code: status_code, payload: body['payload'])
    end

    def put_step_payload(action_id, step_name, payload)
      return Result.new(status_code: 603, error: 'Init required') unless @initialized

      body_json = JSON.generate(actionId: action_id, stepname: step_name, payload: payload)
      status_code, body = Wbs.do_request(:post, "#{@base_url}/v1/rtstep/payload", @headers, body_json)
      return Result.new(status_code: status_code, error: 'inaccessible') if status_code.zero?
      return Wbs.api_error(status_code, body) if status_code >= 400

      Result.new(status_code: status_code)
    end

    def get_step_payload(action_id, step_name)
      return Result.new(status_code: 603, error: 'Init required') unless @initialized

      status_code, body = Wbs.do_request(
        :get,
        "#{@base_url}/v1/rtstep/payload/#{action_id}/#{step_name}",
        @headers
      )
      return Result.new(status_code: status_code, error: 'inaccessible') if status_code.zero?
      return Wbs.api_error(status_code, body) if status_code >= 400
      return Result.new(status_code: status_code, error: 'inaccessible') if body.nil?

      Result.new(status_code: status_code, payload: body['payload'])
    end

    def get_keystore(keylist)
      return Result.new(status_code: 603, error: 'Init required') unless @initialized

      keys = keylist.gsub(' ', '')
      status_code, body = Wbs.do_request(:get, "#{@base_url}/v1/keystore/#{keys}", @headers)
      return Result.new(status_code: status_code, error: 'inaccessible') if status_code.zero?
      return Wbs.api_error(status_code, body) if status_code >= 400
      return Result.new(status_code: status_code, error: 'inaccessible') if body.nil?

      keys.split(',').each do |key|
        next if key.empty?
        return Result.new(status_code: 605, error: "#{key} not found") unless body.key?(key)
      end
      Result.new(status_code: status_code, answer: body)
    end
  end
end
