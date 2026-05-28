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

import org.w3c.dom.Element
import java.io.{ByteArrayInputStream, StringWriter}
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult

object TransformClient:
  def JsonParse(text: String): Result =
    try Result.ok(Map("data" -> JsonUtil.parse(text)))
    catch case e: Exception => Result.error(400, e.getMessage)

  def JsonStringify(data: Any, indent: Integer = null): Result =
    try Result.ok(Map("text" -> JsonUtil.stringify(data)))
    catch case e: Exception => Result.error(400, e.getMessage)

  def CsvToRows(text: String, delimiter: String = ","): Result =
    try
      val lines = text.split("\r?\n")
      if lines.isEmpty then Result.ok(Map("rows" -> List.empty[Map[String, String]]))
      else
        val headers = lines(0).split(delimiter, -1)
        val rows = lines.drop(1).filter(_.nonEmpty).map { line =>
          val cols = line.split(delimiter, -1)
          headers.zipWithIndex.map { case (h, i) => h -> (if i < cols.length then cols(i) else "") }.toMap
        }
        Result.ok(Map("rows" -> rows))
    catch case e: Exception => Result.error(400, e.getMessage)

  def RowsToCsv(rows: java.util.List[java.util.Map[String, String]], delimiter: String = ","): Result =
    if rows == null || rows.isEmpty then Result.error(400, "rows must not be empty")
    else try
      val list = rows.toArray.map(_.asInstanceOf[java.util.Map[String, String]])
      val headers = list(0).keySet().toArray.map(_.toString).toList
      val sb = new StringBuilder(headers.mkString(delimiter)).append('\n')
      list.foreach { row =>
        sb.append(headers.map(h => Option(row.get(h)).getOrElse("")).mkString(delimiter)).append('\n')
      }
      Result.ok(Map("text" -> sb.toString))
    catch case e: Exception => Result.error(400, e.getMessage)

  def XmlToDict(text: String): Result =
    try
      val doc = DocumentBuilderFactory.newInstance.newDocumentBuilder.parse(new ByteArrayInputStream(text.getBytes))
      val root = doc.getDocumentElement
      Result.ok(Map("data" -> Map(root.getTagName -> elem(root))))
    catch case e: Exception => Result.error(400, e.getMessage)

  def DictToXml(data: Map[String, Any], rootTag: String = "root"): Result =
    try
      val doc = DocumentBuilderFactory.newInstance.newDocumentBuilder.newDocument()
      val root = doc.createElement(rootTag); doc.appendChild(root)
      data.foreach { case (k, v) => build(root, v, k) }
      val sw = new StringWriter()
      TransformerFactory.newInstance.newTransformer().transform(new DOMSource(doc), new StreamResult(sw))
      Result.ok(Map("text" -> sw.toString))
    catch case e: Exception => Result.error(400, e.getMessage)

  private def elem(node: Element): Any =
    val children = (0 until node.getChildNodes.getLength)
      .map(node.getChildNodes.item)
      .collect { case e: Element => e }
    if children.isEmpty then Option(node.getTextContent).map(_.trim).getOrElse("")
    else
      val out = scala.collection.mutable.LinkedHashMap[String, Any]()
      children.foreach { child =>
        val v = elem(child); val tag = child.getTagName
        if out.contains(tag) then
          val prev = out(tag)
          out(tag) = prev match
            case l: scala.collection.mutable.ArrayBuffer[_] => l += v; l
            case other => scala.collection.mutable.ArrayBuffer(other, v)
        else out(tag) = v
      }
      out.toMap

  private def build(parent: org.w3c.dom.Element, obj: Any, tag: String): Unit =
    val doc = parent.getOwnerDocument
    obj match
      case m: Map[_, _] =>
        val node = doc.createElement(tag); parent.appendChild(node)
        m.foreach { case (k, v) => build(node, v, k.toString) }
      case it: Iterable[_] =>
        it.foreach(v => build(parent, v, tag))
      case other =>
        val node = doc.createElement(tag)
        node.setTextContent(if other == null then "" else other.toString)
        parent.appendChild(node)
