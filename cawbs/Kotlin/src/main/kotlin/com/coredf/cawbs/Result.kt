// Copyright Core DF

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.coredf.cawbs

data class Result(
    val statusCode: Int,
    val error: Any? = null,
    val payload: Any? = null,
    val answer: Map<String, Any?>? = null
) {
    fun toMap(): Map<String, Any?> = buildMap {
        put("status_code", statusCode)
        error?.let { put("error", it) }
        payload?.let { put("payload", it) }
        answer?.let { put("answer", it) }
    }
}
