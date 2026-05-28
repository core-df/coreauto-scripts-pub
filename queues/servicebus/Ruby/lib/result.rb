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

module CoreautoResult
  module_function
  def missing_env(vars)
    { status_code: 601, error: "Environment variables \#{vars} should be defined" }
  end
  def transport_error(message = 'inaccessible')
    { status_code: 0, error: message }
  end
end
