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

final case class Result(
    statusCode: Int,
    error: Option[Any] = None,
    payload: Option[Any] = None,
    answer: Option[Map[String, Any]] = None
):
  def toMap: Map[String, Any] =
    Map("status_code" -> statusCode) ++
      error.map("error" -> _).toMap ++
      payload.map("payload" -> _).toMap ++
      answer.map("answer" -> _).toMap
