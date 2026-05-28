// Copyright (c) Core DF. All rights reserved.

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
