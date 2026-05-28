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

package com.coredf.transform

internal object JsonUtil {
    fun parse(json: String?): Any? {
        if (json.isNullOrBlank()) return null
        return SimpleJson.parseValue(json.trim(), intArrayOf(0))
    }

    fun stringify(value: Any?): String = SimpleJson.stringify(value)
}

private object SimpleJson {
    fun parseValue(s: String, i: IntArray): Any? {
        skipWs(s, i)
        if (i[0] >= s.length) return null
        return when (s[i[0]]) {
            '{' -> parseObject(s, i)
            '[' -> parseArray(s, i)
            '"' -> parseString(s, i)
            else -> when {
                s.startsWith("true", i[0]) -> { i[0] += 4; true }
                s.startsWith("false", i[0]) -> { i[0] += 5; false }
                s.startsWith("null", i[0]) -> { i[0] += 4; null }
                else -> parseNumber(s, i)
            }
        }
    }

    fun parseObject(s: String, i: IntArray): LinkedHashMap<String, Any?> {
        val map = linkedMapOf<String, Any?>()
        i[0]++
        skipWs(s, i)
        if (peek(s, i) == '}') {
            i[0]++
            return map
        }
        while (true) {
            skipWs(s, i)
            val key = parseString(s, i)
            skipWs(s, i)
            i[0]++
            map[key] = parseValue(s, i)
            skipWs(s, i)
            if (s[i[0]++] == '}') break
        }
        return map
    }

    fun parseArray(s: String, i: IntArray): MutableList<Any?> {
        val list = mutableListOf<Any?>()
        i[0]++
        skipWs(s, i)
        if (peek(s, i) == ']') {
            i[0]++
            return list
        }
        while (true) {
            list.add(parseValue(s, i))
            skipWs(s, i)
            if (s[i[0]++] == ']') break
        }
        return list
    }

    fun parseString(s: String, i: IntArray): String {
        i[0]++
        val sb = StringBuilder()
        while (i[0] < s.length) {
            val c = s[i[0]++]
            if (c == '"') break
            sb.append(c)
        }
        return sb.toString()
    }

    fun parseNumber(s: String, i: IntArray): Number {
        val start = i[0]
        while (i[0] < s.length && "0123456789+-.".contains(s[i[0]])) i[0]++
        val num = s.substring(start, i[0])
        return if ('.' in num) num.toDouble() else num.toLong()
    }

    fun skipWs(s: String, i: IntArray) {
        while (i[0] < s.length && s[i[0]].isWhitespace()) i[0]++
    }

    fun peek(s: String, i: IntArray): Char {
        skipWs(s, i)
        return s[i[0]]
    }

    fun stringify(value: Any?): String = when (value) {
        null -> "null"
        is String -> "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""
        is Boolean, is Number -> value.toString()
        is Map<*, *> -> "{" + value.entries.joinToString(",") { stringify(it.key.toString()) + ":" + stringify(it.value) } + "}"
        is Iterable<*> -> "[" + value.joinToString(",") { stringify(it) } + "]"
        else -> stringify(value.toString())
    }
}
