# frozen_string_literal: true

# Copyright Core DF — Apache License 2.0

require 'fileutils'
require_relative '../../../http/Ruby/lib/result'

module Fileclient
  module_function

  def LocalRead(path, encoding: 'utf-8')
    { status_code: 200, content: File.read(path, encoding: encoding) }
  rescue StandardError => e
    { status_code: 500, error: e.message }
  end

  def LocalWrite(path, content, encoding: 'utf-8')
    FileUtils.mkdir_p(File.dirname(path)) unless File.dirname(path).empty?
    File.write(path, content, encoding: encoding)
    { status_code: 200 }
  rescue StandardError => e
    { status_code: 500, error: e.message }
  end

  def LocalMove(src, dest)
    FileUtils.mv(src, dest)
    { status_code: 200 }
  rescue StandardError => e
    { status_code: 500, error: e.message }
  end

  def _sftp_connect
    require 'net/sftp'
    host = ENV['SFTP_HOST']
    user = ENV['SFTP_USER']
    password = ENV['SFTP_PASSWORD']
    port = (ENV['SFTP_PORT'] || '22').to_i
    key_path = ENV['SFTP_PRIVATE_KEY']
    raise 'SFTP_HOST and SFTP_USER required' if host.to_s.empty? || user.to_s.empty?

    if key_path && !key_path.empty?
      Net::SFTP.start(host, user, port: port, keys: [key_path], non_interactive: true) { |sftp| yield sftp }
    else
      raise 'SFTP_PASSWORD or SFTP_PRIVATE_KEY required' if password.to_s.empty?
      Net::SFTP.start(host, user, password: password, port: port, non_interactive: true) { |sftp| yield sftp }
    end
  end

  def SftpGet(remote_path, local_path)
    _sftp_connect do |sftp|
      FileUtils.mkdir_p(File.dirname(local_path)) unless File.dirname(local_path).empty?
      sftp.download!(remote_path, local_path)
    end
    { status_code: 200 }
  rescue LoadError
    { status_code: 500, error: 'net-sftp gem required' }
  rescue StandardError => e
    { status_code: 500, error: e.message }
  end

  def SftpPut(local_path, remote_path)
    _sftp_connect do |sftp|
      sftp.upload!(local_path, remote_path)
    end
    { status_code: 200 }
  rescue LoadError
    { status_code: 500, error: 'net-sftp gem required' }
  rescue StandardError => e
    { status_code: 500, error: e.message }
  end
end
