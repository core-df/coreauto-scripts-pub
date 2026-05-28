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
import java.io.ByteArrayInputStream
import java.io.StringWriter
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult

object TransformClient {
    @JvmStatic fun JsonParse(text: String) = try { Result.ok(mapOf("data" to JsonUtil.parse(text))) } catch (e: Exception) { Result.error(400, e.message) }
    @JvmStatic fun JsonStringify(data: Any?, indent: Int? = null) = try { Result.ok(mapOf("text" to JsonUtil.stringify(data))) } catch (e: Exception) { Result.error(400, e.message) }
    @JvmStatic fun CsvToRows(text: String, delimiter: String = ",") = try {
        val lines = text.split("\r?\n".toRegex())
        if (lines.isEmpty()) return Result.ok(mapOf("rows" to emptyList<Map<String,String>>()))
        val headers = lines[0].split(delimiter)
        val rows = lines.drop(1).filter { it.isNotEmpty() }.map { line ->
            val cols = line.split(delimiter)
            headers.mapIndexed { i, h -> h to (cols.getOrNull(i) ?: "") }.toMap()
        }
        Result.ok(mapOf("rows" to rows))
    } catch (e: Exception) { Result.error(400, e.message) }

    @JvmStatic fun RowsToCsv(rows: List<Map<String, String>>, delimiter: String = ","): Result {
        if (rows.isEmpty()) return Result.error(400, "rows must not be empty")
        val headers = rows[0].keys.toList()
        val sb = StringBuilder(headers.joinToString(delimiter)).append('\n')
        rows.forEach { row -> sb.append(headers.joinToString(delimiter) { row[it] ?: "" }).append('\n') }
        return Result.ok(mapOf("text" to sb.toString()))
    }

    @JvmStatic fun XmlToDict(text: String) = try {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(ByteArrayInputStream(text.toByteArray()))
        val root = doc.documentElement; Result.ok(mapOf("data" to mapOf(root.tagName to elem(root))))
    } catch (e: Exception) { Result.error(400, e.message) }

    @JvmStatic fun DictToXml(data: Map<String, Any?>, rootTag: String = "root") = try {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument()
        val root = doc.createElement(rootTag); doc.appendChild(root)
        data.forEach { (k, v) -> build(root, v, k) }
        val sw = StringWriter(); TransformerFactory.newInstance().newTransformer().transform(DOMSource(doc), StreamResult(sw))
        Result.ok(mapOf("text" to sw.toString()))
    } catch (e: Exception) { Result.error(400, e.message) }

    private fun elem(node: Element): Any {
        val children = (0 until node.childNodes.length).mapNotNull { i -> node.childNodes.item(i) as? Element }
        if (children.isEmpty()) return node.textContent?.trim() ?: ""
        val out = linkedMapOf<String, Any>()
        children.forEach { child ->
            val v = elem(child); val tag = child.tagName
            if (out.containsKey(tag)) {
                val prev = out[tag]; out[tag] = if (prev is MutableList<*>) { (prev as MutableList<Any>).apply { add(v) }; prev } else mutableListOf(prev!!, v)
            } else out[tag] = v
        }
        return out
    }
    @Suppress("UNCHECKED_CAST")
    private fun build(parent: org.w3c.dom.Element, obj: Any?, tag: String) {
        val doc = parent.ownerDocument
        when (obj) {
            is Map<*, *> -> { val node = doc.createElement(tag); parent.appendChild(node); obj.forEach { (k, v) -> build(node, v, k.toString()) } }
            is List<*> -> obj.forEach { build(parent, it, tag) }
            else -> { val node = doc.createElement(tag); node.textContent = obj?.toString() ?: ""; parent.appendChild(node) }
        }
    }
}
