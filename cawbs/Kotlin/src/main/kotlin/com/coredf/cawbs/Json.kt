// Copyright (c) Core DF. All rights reserved.

package com.coredf.cawbs

internal object Json {
    fun parse(text: String?): Any? {
        if (text.isNullOrBlank()) return null
        return SimpleJson.parseValue(text.trim(), intArrayOf(0))
    }

    fun stringify(value: Any?): String = SimpleJson.stringify(value)

    private object SimpleJson {
        fun parseValue(s: String, i: IntArray): Any? {
            skipWs(s, i)
            if (i[0] >= s.length) return null
            return when (s[i[0]]) {
                '{' -> parseObject(s, i)
                '[' -> parseArray(s, i)
                '"' -> parseString(s, i)
                't' -> if (s.startsWith("true", i[0])) { i[0] += 4; true } else parseNumber(s, i)
                'f' -> if (s.startsWith("false", i[0])) { i[0] += 5; false } else parseNumber(s, i)
                'n' -> if (s.startsWith("null", i[0])) { i[0] += 4; null } else parseNumber(s, i)
                else -> parseNumber(s, i)
            }
        }

        fun parseObject(s: String, i: IntArray): MutableMap<String, Any?> {
            val map = linkedMapOf<String, Any?>()
            i[0]++
            skipWs(s, i)
            if (peek(s, i) == '}') { i[0]++; return map }
            while (true) {
                skipWs(s, i)
                val key = parseString(s, i)
                skipWs(s, i)
                i[0]++
                map[key] = parseValue(s, i)
                skipWs(s, i)
                when (s[i[0]++]) {
                    '}' -> break
                }
            }
            return map
        }

        fun parseArray(s: String, i: IntArray): MutableList<Any?> {
            val list = mutableListOf<Any?>()
            i[0]++
            skipWs(s, i)
            if (peek(s, i) == ']') { i[0]++; return list }
            while (true) {
                list.add(parseValue(s, i))
                skipWs(s, i)
                when (s[i[0]++]) {
                    ']' -> break
                }
            }
            return list
        }

        fun parseString(s: String, i: IntArray): String {
            i[0]++
            val sb = StringBuilder()
            while (i[0] < s.length) {
                when (val c = s[i[0]++]) {
                    '"' -> break
                    '\\' -> sb.append(
                        when (val esc = s[i[0]++]) {
                            '"', '\\', '/' -> esc
                            'b' -> '\b'
                            'f' -> '\u000C'
                            'n' -> '\n'
                            'r' -> '\r'
                            't' -> '\t'
                            'u' -> s.substring(i[0], i[0] + 4).also { i[0] += 4 }.toInt(16).toChar()
                            else -> esc
                        }
                    )
                    else -> sb.append(c)
                }
            }
            return sb.toString()
        }

        fun parseNumber(s: String, i: IntArray): Number {
            val start = i[0]
            while (i[0] < s.length) {
                val c = s[i[0]]
                if (!(c.isDigit() || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E')) break
                i[0]++
            }
            val num = s.substring(start, i[0])
            return if ('.' in num || 'e' in num || 'E' in num) num.toDouble() else num.toLong()
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
            is Boolean -> value.toString()
            is Number -> value.toString()
            is Map<*, *> -> buildString {
                append('{')
                value.entries.joinTo(this, ",") { (k, v) ->
                    "${stringify(k.toString())}:${stringify(v)}"
                }
                append('}')
            }
            is Iterable<*> -> buildString {
                append('[')
                value.joinTo(this, ",") { stringify(it) }
                append(']')
            }
            else -> stringify(value.toString())
        }
    }
}
