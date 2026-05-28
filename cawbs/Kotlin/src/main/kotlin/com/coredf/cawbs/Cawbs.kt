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

object Cawbs {
    private val sess = WbsSession()

    @JvmStatic
    fun init(): Result {
        val env = System.getenv("ENV").orEmpty()
        val actionId = System.getenv("ACTIONID").orEmpty()
        val accessCode = System.getenv("CA_ACCESS_CODE").orEmpty()
        val baseUrl = System.getenv("CA_WBS_URL").orEmpty()
        val stepName = System.getenv("STEPNAME").orEmpty()
        if (env.isBlank() || actionId.isBlank() || accessCode.isBlank() || baseUrl.isBlank() || stepName.isBlank()) {
            return WbsSession.missingEnv("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME")
        }
        return sess.authenticate(env, accessCode, baseUrl)
    }

    @JvmStatic fun getEventPayload(): Result = sess.getEventPayload(System.getenv("ACTIONID").orEmpty())
    @JvmStatic fun putStepPayload(payload: Any?): Result =
        sess.putStepPayload(System.getenv("ACTIONID").orEmpty(), System.getenv("STEPNAME").orEmpty(), payload)
    @JvmStatic fun getStepPayload(stepname: String): Result =
        sess.getStepPayload(System.getenv("ACTIONID").orEmpty(), stepname)
    @JvmStatic fun getKeystore(keylist: String): Result = sess.getKeystore(keylist)
}
