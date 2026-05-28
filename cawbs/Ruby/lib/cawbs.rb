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
# Core Auto Web Services library (cawbs) — Ruby client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

require_relative 'wbs'

module Cawbs
  @sess = Wbs::Session.new

  module_function

  def Init
    env = ENV['ENV']
    action_id = ENV['ACTIONID']
    access_code = ENV['CA_ACCESS_CODE']
    base_url = ENV['CA_WBS_URL']
    step_name = ENV['STEPNAME']
    return Wbs.missing_env('ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME') if
      [env, action_id, access_code, base_url, step_name].any?(&:nil?) || [env, action_id, access_code, base_url, step_name].any?(&:empty?)

    @sess.authenticate(env, access_code, base_url)
  end

  def GetEventPayload
    @sess.get_event_payload(ENV['ACTIONID'])
  end

  def PutStepPayload(payload)
    @sess.put_step_payload(ENV['ACTIONID'], ENV['STEPNAME'], payload)
  end

  def GetStepPayload(stepname)
    @sess.get_step_payload(ENV['ACTIONID'], stepname)
  end

  def GetKeystore(keylist)
    @sess.get_keystore(keylist)
  end
end
