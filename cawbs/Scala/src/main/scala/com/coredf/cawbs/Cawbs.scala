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
//
// Documentation: https://coreauto.coredf.com/resources

package com.coredf.cawbs

object Cawbs:
  private val sess = WbsSession()

  def Init(): Result =
    val env = sys.env.getOrElse("ENV", "")
    val actionId = sys.env.getOrElse("ACTIONID", "")
    val accessCode = sys.env.getOrElse("CA_ACCESS_CODE", "")
    val baseUrl = sys.env.getOrElse("CA_WBS_URL", "")
    val stepName = sys.env.getOrElse("STEPNAME", "")
    if env.isBlank || actionId.isBlank || accessCode.isBlank || baseUrl.isBlank || stepName.isBlank then
      WbsSession.missingEnv("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME")
    else sess.authenticate(env, accessCode, baseUrl)

  def GetEventPayload(): Result = sess.getEventPayload(sys.env.getOrElse("ACTIONID", ""))
  def PutStepPayload(payload: Any): Result =
    sess.putStepPayload(sys.env.getOrElse("ACTIONID", ""), sys.env.getOrElse("STEPNAME", ""), payload)
  def GetStepPayload(stepname: String): Result =
    sess.getStepPayload(sys.env.getOrElse("ACTIONID", ""), stepname)
  def GetKeystore(keylist: String): Result = sess.getKeystore(keylist)

object CawbsBatch:
  private val sess = WbsSession()

  def Init(): Result =
    val env = sys.env.getOrElse("ENV", "")
    val accessCode = sys.env.getOrElse("CA_ACCESS_CODE", "")
    val baseUrl = sys.env.getOrElse("CA_WBS_URL", "")
    if env.isBlank || accessCode.isBlank || baseUrl.isBlank then
      WbsSession.missingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL")
    else sess.authenticate(env, accessCode, baseUrl)

  def GetKeystore(keylist: String): Result = sess.getKeystore(keylist)
