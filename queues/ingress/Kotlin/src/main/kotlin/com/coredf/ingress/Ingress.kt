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

package com.coredf.ingress;

import com.coredf.cawbs.CawbsIngress;

object Ingress {
    @JvmStatic
    fun TriggerEvent(payload: Any?, eventName: String? = null, eventSource: String? = null): Result {
        val name = eventName ?: env("CA_EVENT_NAME")
        if (name.isEmpty()) return Result.missingEnv("CA_EVENT_NAME (or pass event_name)")
        val source = eventSource ?: env("CA_EVENT_SOURCE")
        val init = CawbsIngress.Init()
        if (init.statusCode >= 400) return fromCawbs(init)
        return fromCawbs(CawbsIngress.PostEvent(name, payload, source.ifEmpty { null }))
    }

    @JvmStatic
    fun ForwardMessages(consumeResult: Result): Result {
        if (consumeResult.statusCode != 200) return consumeResult
        @Suppress("UNCHECKED_CAST")
        val msgs = consumeResult.get("messages") as? List<Map<String, Any?>> ?: emptyList()
        val forwarded = mutableListOf<Map<String, Any?>>()
        for (msg in msgs) {
            val value = msg["value"] ?: msg
            val posted = TriggerEvent(value)
            if (posted.statusCode >= 400) return posted
            forwarded.add(buildMap {
                posted.get("actionId")?.let { put("actionId", it) }
                posted.get("eventId")?.let { put("eventId", it) }
            })
        }
        return Result.ok(mapOf("forwarded" to forwarded))
    }

    @JvmStatic
    fun RunBridge(consumeFn: () -> Result): Result = ForwardMessages(consumeFn())

    private fun fromCawbs(r: com.coredf.cawbs.Result): Result {
        val fields = linkedMapOf<String, Any?>()
        r.answer?.let { fields.putAll(it) }
        r.error?.let { fields["error"] = it }
        r.payload?.let { fields["payload"] = it }
        return Result(r.statusCode, fields)
    }

    private fun env(key: String): String = System.getenv(key) ?: ""
}
