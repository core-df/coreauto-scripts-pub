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

import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.time.Duration

class WbsSession {
    private var initialized = false
    private var baseUrl = ""
    private var env = ""
    private var token = ""

    private val http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(60)).build()

    companion object {
        fun missingEnv(vars: String) = Result(
            statusCode = 601,
            error = "Environment variables $vars should be defined"
        )

        private fun trimUrl(url: String) = url.trim(' ', '/')
    }

    private data class HttpOutcome(val statusCode: Int, val body: String?, val transportError: Boolean)

    private fun request(method: String, url: String, body: String? = null): HttpOutcome = try {
        val builder = HttpRequest.newBuilder(URI.create(url))
            .timeout(Duration.ofSeconds(60))
            .header("Content-Type", "application/json")
            .header("Environment", env)
        if (token.isNotEmpty()) {
            builder.header("Authorization", "Bearer $token")
        }
        if (body != null) {
            builder.method(method, HttpRequest.BodyPublishers.ofString(body))
        } else {
            builder.method(method, HttpRequest.BodyPublishers.noBody())
        }
        val resp = http.send(builder.build(), HttpResponse.BodyHandlers.ofString())
        HttpOutcome(resp.statusCode(), resp.body(), false)
    } catch (_: Exception) {
        HttpOutcome(0, null, true)
    }

    private fun apiError(statusCode: Int, body: String?): Result {
        val err = Json.parse(body)
        return Result(statusCode, err ?: "inaccessible")
    }

    fun authenticate(env: String, accessCode: String, baseUrl: String): Result {
        if (initialized) {
            return Result(602, "init already called")
        }
        this.env = env
        this.baseUrl = trimUrl(baseUrl)
        val todo = Json.stringify(mapOf("apiCode" to accessCode))
        val out = request("POST", "${this.baseUrl}/v1/auth/apicode", todo)
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) as? Map<*, *>
        token = parsed?.get("token")?.toString() ?: ""
        if (token.isEmpty()) return Result(out.statusCode, "inaccessible")
        initialized = true
        return Result(out.statusCode)
    }

    fun getEventPayload(actionId: String): Result {
        if (!initialized) return Result(603, "Init required")
        val out = request("GET", "$baseUrl/v1/rtevent/$actionId")
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) as? Map<*, *>
            ?: return Result(out.statusCode, "inaccessible")
        return Result(out.statusCode, payload = parsed["payload"])
    }

    fun putStepPayload(actionId: String, stepName: String, payload: Any?): Result {
        if (!initialized) return Result(603, "Init required")
        val todo = Json.stringify(mapOf("actionId" to actionId, "stepname" to stepName, "payload" to payload))
        val out = request("POST", "$baseUrl/v1/rtstep/payload", todo)
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        return Result(out.statusCode)
    }

    fun getStepPayload(actionId: String, stepName: String): Result {
        if (!initialized) return Result(603, "Init required")
        val out = request("GET", "$baseUrl/v1/rtstep/payload/$actionId/$stepName")
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) as? Map<*, *>
            ?: return Result(out.statusCode, "inaccessible")
        return Result(out.statusCode, payload = parsed["payload"])
    }

    fun postEvent(eventName: String, payload: Any?, eventSource: String? = null): Result {
        if (!initialized) return Result(603, "Init required")
        val body = buildMap<String, Any?> {
            put("eventName", eventName)
            put("payload", payload)
            if (eventSource != null) put("eventSource", eventSource)
        }
        val out = request("POST", "$baseUrl/v1/rtevent", Json.stringify(body))
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) as? Map<*, *>
            ?: return Result(out.statusCode, "inaccessible")
        val resultPayload = buildMap<String, Any?> {
            parsed["eventId"]?.let { put("eventId", it) }
            parsed["actionId"]?.let { put("actionId", it) }
            parsed["createdAt"]?.let { put("createdAt", it) }
        }
        return Result(out.statusCode, payload = resultPayload)
    }

    fun getEventStatus(actionId: String): Result {
        if (!initialized) return Result(603, "Init required")
        val out = request("GET", "$baseUrl/v1/rtevent/status/$actionId")
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) ?: return Result(out.statusCode, "inaccessible")
        return Result(out.statusCode, payload = parsed)
    }

    fun getEventList(): Result {
        if (!initialized) return Result(603, "Init required")
        val out = request("GET", "$baseUrl/v1/rtevent/list")
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) ?: return Result(out.statusCode, "inaccessible")
        return Result(out.statusCode, payload = parsed)
    }

    fun submitFlag(name: String, systemName: String, sourceSystemName: String, date: String): Result {
        if (!initialized) return Result(603, "Init required")
        val body = mapOf(
            "name" to name,
            "systemName" to systemName,
            "sourceSystemName" to sourceSystemName,
            "date" to date,
        )
        val out = request("POST", "$baseUrl/v1/flag", Json.stringify(body))
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) as? Map<*, *>
            ?: return Result(out.statusCode, "inaccessible")
        val resultPayload = parsed["status"]?.let { mapOf("flagStatus" to it) }
        return Result(out.statusCode, payload = resultPayload)
    }

    @Suppress("UNCHECKED_CAST")
    fun getKeystore(keylist: String): Result {
        if (!initialized) return Result(603, "Init required")
        val keys = keylist.replace(" ", "")
        val out = request("GET", "$baseUrl/v1/keystore/$keys")
        if (out.transportError) return Result(out.statusCode, "inaccessible")
        if (out.statusCode >= 400) return apiError(out.statusCode, out.body)
        val parsed = Json.parse(out.body) as? Map<String, Any?>
            ?: return Result(out.statusCode, "inaccessible")
        for (key in keys.split(",")) {
            if (key.isEmpty()) continue
            if (!parsed.containsKey(key)) return Result(605, "$key not found")
        }
        return Result(out.statusCode, answer = parsed)
    }
}
