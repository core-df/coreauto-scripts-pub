// Copyright (c) Core DF. All rights reserved.
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
