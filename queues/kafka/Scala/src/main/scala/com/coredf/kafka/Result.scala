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

package com.coredf.kafka
import scala.collection.mutable
final case class Result(statusCode: Int, fields: Map[String, Any] = Map.empty) {
  def get(key: String): Any = fields.getOrElse(key, null)
  def toMap: Map[String, Any] = mutable.LinkedHashMap("status_code" -> statusCode) ++ fields
}
object Result {
  def ok(fields: Map[String, Any] = Map.empty) = Result(200, fields)
  def error(code: Int, error: Any) = Result(code, Map("error" -> error))
  def missingEnv(v: String) = error(601, s"Environment variables $v should be defined")
  def transportError(m: String = "inaccessible") = error(0, m)
}
