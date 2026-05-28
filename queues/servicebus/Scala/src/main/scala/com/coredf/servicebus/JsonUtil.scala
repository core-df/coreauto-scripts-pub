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

package com.coredf.servicebus

private object JsonUtil:
  def parse(json: String): Any =
    if json == null || json.isBlank then null
    else SimpleJson.parseValue(json.trim, Array(0))

  def stringify(value: Any): String = SimpleJson.stringify(value)

private object SimpleJson:
  def parseValue(s: String, i: Array[Int]): Any =
    skipWs(s, i)
    if i(0) >= s.length then null
    else s(i(0)) match
      case '{' => parseObject(s, i)
      case '[' => parseArray(s, i)
      case '"' => parseString(s, i)
      case _ if s.startsWith("true", i(0))  => i(0) += 4; true
      case _ if s.startsWith("false", i(0)) => i(0) += 5; false
      case _ if s.startsWith("null", i(0))   => i(0) += 4; null
      case _ => parseNumber(s, i)

  def parseObject(s: String, i: Array[Int]): scala.collection.mutable.LinkedHashMap[String, Any] =
    val map = scala.collection.mutable.LinkedHashMap[String, Any]()
    i(0) += 1; skipWs(s, i)
    if peek(s, i) == '}' then i(0) += 1; return map
    while true do
      skipWs(s, i)
      val key = parseString(s, i); skipWs(s, i); i(0) += 1
      map(key) = parseValue(s, i); skipWs(s, i)
      val ch = s(i(0)); i(0) += 1
      if ch == '}' then return map

  def parseArray(s: String, i: Array[Int]): scala.collection.mutable.ArrayBuffer[Any] =
    val list = scala.collection.mutable.ArrayBuffer[Any]()
    i(0) += 1; skipWs(s, i)
    if peek(s, i) == ']' then i(0) += 1; return list
    while true do
      list += parseValue(s, i); skipWs(s, i)
      val ch = s(i(0)); i(0) += 1
      if ch == ']' then return list

  def parseString(s: String, i: Array[Int]): String =
    i(0) += 1
    val sb = new StringBuilder
    while i(0) < s.length do
      val c = s(i(0)); i(0) += 1
      if c == '"' then return sb.toString
      sb.append(c)
    sb.toString

  def parseNumber(s: String, i: Array[Int]): Number =
    val start = i(0)
    while i(0) < s.length && "0123456789+-.".contains(s(i(0))) do i(0) += 1
    val num = s.substring(start, i(0))
    if num.contains(".") then java.lang.Double.valueOf(num) else java.lang.Long.valueOf(num)

  def skipWs(s: String, i: Array[Int]): Unit =
    while i(0) < s.length && s(i(0)).isWhitespace do i(0) += 1

  def peek(s: String, i: Array[Int]): Char = skipWs(s, i); s(i(0))

  def stringify(value: Any): String = value match
    case null => "null"
    case s: String => "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    case b: Boolean => b.toString
    case n: Number => n.toString
    case m: Map[_, _] =>
      "{" + m.map { case (k, v) => stringify(k.toString) + ":" + stringify(v) }.mkString(",") + "}"
    case it: Iterable[_] => "[" + it.map(stringify).mkString(",") + "]"
    case other => stringify(other.toString)
