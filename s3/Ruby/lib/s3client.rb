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

require 'aws-sdk-s3'
require_relative '../../../http/Ruby/lib/result'

module S3client
  module_function

  def aws_client
    region = ENV['AWS_REGION'] || ENV['AWS_DEFAULT_REGION'] || 'us-east-1'
    opts = { region: region }
    endpoint = ENV['S3_ENDPOINT_URL']
    if endpoint && !endpoint.empty?
      opts[:endpoint] = endpoint
      opts[:force_path_style] = true
    end
    Aws::S3::Client.new(opts)
  end

  def bucket(explicit = nil)
    explicit && !explicit.empty? ? explicit : ENV['S3_BUCKET']
  end

  def Init
    if ENV['AWS_ACCESS_KEY_ID'].to_s.empty? && ENV['AWS_PROFILE'].to_s.empty?
      return CoreautoResult.missing_env('AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE')
    end
    return CoreautoResult.missing_env('S3_BUCKET (or pass bucket per call)') if ENV['S3_BUCKET'].to_s.empty?

    { status_code: 200 }
  end

  def GetObject(key, bucket_name = nil)
    b = bucket(bucket_name)
    return CoreautoResult.missing_env('S3_BUCKET') if b.to_s.empty?

    resp = aws_client.get_object(bucket: b, key: key)
    raw = resp.body.read
    text = raw.dup.force_encoding(Encoding::UTF_8)
    content = text.valid_encoding? ? text : raw
    { status_code: 200, content: content }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def PutObject(key, content, bucket_name = nil)
    b = bucket(bucket_name)
    return CoreautoResult.missing_env('S3_BUCKET') if b.to_s.empty?

    aws_client.put_object(bucket: b, key: key, body: content)
    { status_code: 200 }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end

  def ListObjects(prefix = '', bucket_name = nil)
    b = bucket(bucket_name)
    return CoreautoResult.missing_env('S3_BUCKET') if b.to_s.empty?

    resp = aws_client.list_objects_v2(bucket: b, prefix: prefix)
    keys = (resp.contents || []).map(&:key)
    { status_code: 200, keys: keys }
  rescue StandardError => e
    CoreautoResult.transport_error(e.message)
  end
end
