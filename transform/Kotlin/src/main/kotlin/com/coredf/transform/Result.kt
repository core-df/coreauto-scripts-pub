// Copyright Core DF
//
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

package com.coredf.transform
class Result private constructor(val statusCode: Int, val fields: Map<String, Any?> = emptyMap()) {
  fun get(key: String): Any? = fields[key]
  fun toMap() = linkedMapOf<String, Any?>("status_code" to statusCode).apply { putAll(fields) }
  companion object {
    fun ok(fields: Map<String, Any?> = emptyMap()) = Result(200, fields)
    fun error(code: Int, error: Any?) = Result(code, mapOf("error" to error))
    fun missingEnv(v: String) = error(601, "Environment variables $v should be defined")
    fun transportError(m: String? = "inaccessible") = error(0, m ?: "inaccessible")
  }
}
