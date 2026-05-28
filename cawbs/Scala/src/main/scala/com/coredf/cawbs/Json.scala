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

object Json:
  def parse(text: String): Option[Any] =
    if text == null || text.isBlank then None
    else Some(SimpleJson.parseValue(text.trim, Array(0)))

  def stringify(value: Any): String = SimpleJson.stringify(value)

  private object SimpleJson:
    def parseValue(s: String, i: Array[Int]): Any =
      skipWs(s, i)
      if i(0) >= s.length then null
      else s(i(0)) match
        case '{' => parseObject(s, i)
        case '[' => parseArray(s, i)
        case '"' => parseString(s, i)
        case 't' if s.startsWith("true", i(0))  => i(0) += 4; true
        case 'f' if s.startsWith("false", i(0)) => i(0) += 5; false
        case 'n' if s.startsWith("null", i(0))  => i(0) += 4; null
        case _                                   => parseNumber(s, i)

    def parseObject(s: String, i: Array[Int]): Map[String, Any] =
      i(0) += 1
      val map = scala.collection.mutable.LinkedHashMap.empty[String, Any]
      skipWs(s, i)
      if peek(s, i) == '}' then i(0) += 1; return map.toMap
      while true do
        skipWs(s, i)
        val key = parseString(s, i)
        skipWs(s, i); i(0) += 1
        map(key) = parseValue(s, i)
        skipWs(s, i)
        s(i(0)) match
          case '}' => i(0) += 1; return map.toMap
          case _   => i(0) += 1

    def parseArray(s: String, i: Array[Int]): List[Any] =
      i(0) += 1
      val list = scala.collection.mutable.ListBuffer.empty[Any]
      skipWs(s, i)
      if peek(s, i) == ']' then i(0) += 1; return list.toList
      while true do
        list += parseValue(s, i)
        skipWs(s, i)
        s(i(0)) match
          case ']' => i(0) += 1; return list.toList
          case _   => i(0) += 1

    def parseString(s: String, i: Array[Int]): String =
      i(0) += 1
      val sb = StringBuilder()
      while i(0) < s.length do
        s(i(0)) match
          case '"' => i(0) += 1; return sb.result()
          case '\\' =>
            i(0) += 1
            sb.append(s(i(0)) match
              case 'n' => '\n'
              case 't' => '\t'
              case 'r' => '\r'
              case c   => c)
            i(0) += 1
          case c => sb.append(c); i(0) += 1
      sb.result()

    def parseNumber(s: String, i: Array[Int]): Number =
      val start = i(0)
      while i(0) < s.length && s(i(0)).toString.matches("[\\d\\.eE\\-+]+") do i(0) += 1
      val num = s.substring(start, i(0))
      if num.contains(".") || num.contains("e") || num.contains("E") then num.toDouble else num.toLong

    def skipWs(s: String, i: Array[Int]): Unit =
      while i(0) < s.length && s(i(0)).isWhitespace do i(0) += 1

    def peek(s: String, i: Array[Int]): Char = { skipWs(s, i); s(i(0)) }

    def stringify(value: Any): String = value match
      case null          => "null"
      case b: Boolean    => b.toString
      case n: Number     => n.toString
      case s: String     => "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
      case m: Map[?, ?]  => "{" + m.map { case (k, v) => s"${stringify(k.toString)}:${stringify(v)}" }.mkString(",") + "}"
      case it: Iterable[?] => "[" + it.map(stringify).mkString(",") + "]"
      case other         => stringify(other.toString)
