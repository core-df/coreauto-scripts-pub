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

object CawbsIngress {
    private val sess = WbsSession()

    @JvmStatic
    fun init(): Result {
        val env = System.getenv("ENV").orEmpty()
        val accessCode = System.getenv("CA_ACCESS_CODE").orEmpty()
        val baseUrl = System.getenv("CA_WBS_URL").orEmpty()
        if (env.isBlank() || accessCode.isBlank() || baseUrl.isBlank()) {
            return WbsSession.missingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL")
        }
        return sess.authenticate(env, accessCode, baseUrl)
    }

    @JvmStatic
    fun postEvent(eventName: String, payload: Any?, eventSource: String? = null): Result =
        sess.postEvent(eventName, payload, eventSource)

    @JvmStatic fun getEventStatus(actionId: String): Result = sess.getEventStatus(actionId)

    @JvmStatic fun getEventList(): Result = sess.getEventList()

    @JvmStatic
    fun submitFlag(name: String, systemName: String, sourceSystemName: String, date: String): Result =
        sess.submitFlag(name, systemName, sourceSystemName, date)

    @JvmStatic fun getKeystore(keylist: String): Result = sess.getKeystore(keylist)
}
