# frozen_string_literal: true

# Copyright (c) Core DF. All rights reserved.
#
# Batch-oriented cawbs client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

require_relative 'wbs'

module Cawbsbatch
  @sess = Wbs::Session.new

  module_function

  def Init
    env = ENV['ENV']
    access_code = ENV['CA_ACCESS_CODE']
    base_url = ENV['CA_WBS_URL']
    return Wbs.missing_env('ENV, CA_ACCESS_CODE, CA_WBS_URL') if
      [env, access_code, base_url].any?(&:nil?) || [env, access_code, base_url].any?(&:empty?)

    @sess.authenticate(env, access_code, base_url)
  end

  def GetKeystore(keylist)
    @sess.get_keystore(keylist)
  end
end
