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
# Ingress-oriented cawbs client for the Core Auto Collector.
#
# Documentation: https://coreauto.coredf.com/resources

require_relative 'wbs'

module Cawbsingress
  @sess = Wbs::Session.new

  module_function

  def Init
    env = ENV['ENV']
    access_code = ENV['CA_ACCESS_CODE']
    base_url = ENV['CA_WBS_URL']
    return Wbs.missing_env('ENV, CA_ACCESS_CODE, CA_WBS_URL') if
      [env, access_code, base_url].any?(&:nil?) || [env, access_code, base_url].any?(&:empty?)

    @sess.authenticate(env, access_code, base_url).to_h
  end

  def PostEvent(event_name, payload, event_source: nil)
    r = @sess.post_event(event_name, payload, event_source: event_source)
    return r.to_h if r.error

    js = r.payload
    {
      status_code: r.status_code,
      eventId: js['eventId'],
      actionId: js['actionId'],
      createdAt: js['createdAt']
    }
  end

  def GetEventStatus(action_id)
    r = @sess.get_event_status(action_id)
    return r.to_h if r.error

    { status_code: r.status_code, status: r.payload }
  end

  def GetEventList
    r = @sess.get_event_list
    return r.to_h if r.error

    { status_code: r.status_code, events: r.payload }
  end

  def SubmitFlag(name, system_name, source_system_name, date)
    r = @sess.submit_flag(name, system_name, source_system_name, date)
    return r.to_h if r.error

    { status_code: r.status_code, flagStatus: r.payload['status'] }
  end

  def GetKeystore(keylist)
    @sess.get_keystore(keylist).to_h
  end
end
