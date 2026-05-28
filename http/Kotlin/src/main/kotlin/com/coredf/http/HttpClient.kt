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

package com.coredf.http
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.nio.charset.StandardCharsets
import java.time.Duration

object HttpClient {
    private val http = java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(60)).build()

    private fun parseBody(body: String?): Any? {
        if (body.isNullOrEmpty()) return null
        val t = body.trim()
        if ((t.startsWith("{") && t.endsWith("}")) || (t.startsWith("[") && t.endsWith("]"))) {
            try { return JsonUtil.parse(body) } catch (_: Exception) {}
        }
        return body
    }

    private fun request(method: String, url: String, headers: Map<String, String>?, jsonBody: String?, params: Map<String, String>?): Result {
        return try {
            var u = url
            if (!params.isNullOrEmpty()) {
                val qs = params.entries.joinToString("&") { (k, v) ->
                    URLEncoder.encode(k, StandardCharsets.UTF_8) + "=" + URLEncoder.encode(v, StandardCharsets.UTF_8)
                }
                u += if (u.contains("?")) "&$qs" else "?$qs"
            }
            val hdrs = headers?.toMutableMap() ?: mutableMapOf()
            if (jsonBody != null) hdrs.putIfAbsent("Content-Type", "application/json")
            val b = HttpRequest.newBuilder(URI.create(u)).timeout(Duration.ofSeconds(60))
            hdrs.forEach { (k, v) -> b.header(k, v) }
            if (jsonBody != null) b.method(method, HttpRequest.BodyPublishers.ofString(jsonBody))
            else b.method(method, HttpRequest.BodyPublishers.noBody())
            val resp = http.send(b.build(), HttpResponse.BodyHandlers.ofString())
            val body = parseBody(resp.body())
            if (resp.statusCode() >= 400) Result.error(resp.statusCode(), body ?: "inaccessible")
            else Result.ok(mapOf("body" to body))
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    @JvmStatic fun Get(url: String, headers: Map<String, String>? = null, params: Map<String, String>? = null) =
        request("GET", url, headers, null, params)

    @JvmStatic fun Post(url: String, jsonBody: Any? = null, data: String? = null, headers: Map<String, String>? = null): Result {
        val body = if (jsonBody != null) JsonUtil.stringify(jsonBody) else data
        return request("POST", url, headers, body, null)
    }

    @JvmStatic fun Put(url: String, jsonBody: Any? = null, headers: Map<String, String>? = null) =
        request("PUT", url, headers, jsonBody?.let { JsonUtil.stringify(it) }, null)

    @JvmStatic fun Delete(url: String, headers: Map<String, String>? = null) =
        request("DELETE", url, headers, null, null)
}
