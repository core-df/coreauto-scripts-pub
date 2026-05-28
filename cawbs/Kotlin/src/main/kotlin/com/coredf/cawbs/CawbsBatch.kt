// Copyright (c) Core DF. All rights reserved.
//
// Documentation: https://coreauto.coredf.com/resources

package com.coredf.cawbs

object CawbsBatch {
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

    @JvmStatic fun getKeystore(keylist: String): Result = sess.getKeystore(keylist)
}
