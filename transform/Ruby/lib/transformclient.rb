# frozen_string_literal: true

# Copyright Core DF
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'csv'
require 'json'
require 'rexml/document'

module Transformclient
  module_function

  def JsonParse(text)
    { status_code: 200, data: JSON.parse(text) }
  rescue JSON::ParserError => e
    { status_code: 400, error: e.message }
  end

  def JsonStringify(data, indent: nil)
    text = indent ? JSON.pretty_generate(data) : JSON.generate(data)
    { status_code: 200, text: text }
  rescue StandardError => e
    { status_code: 400, error: e.message }
  end

  def CsvToRows(text, delimiter: ',')
    rows = CSV.parse(text, headers: true, col_sep: delimiter).map(&:to_h)
    { status_code: 200, rows: rows }
  rescue CSV::MalformedCSVError => e
    { status_code: 400, error: e.message }
  end

  def RowsToCsv(rows, delimiter: ',')
    return { status_code: 400, error: 'rows must not be empty' } if rows.nil? || rows.empty?

    buf = CSV.generate(col_sep: delimiter) do |csv|
      csv << rows[0].keys
      rows.each { |r| csv << r.values_at(*rows[0].keys) }
    end
    { status_code: 200, text: buf }
  rescue StandardError => e
    { status_code: 400, error: e.message }
  end

  def XmlToDict(text)
    doc = REXML::Document.new(text)
    root = doc.root
    data = { root.name => elem_to_val(root) }
    { status_code: 200, data: data }
  rescue REXML::ParseException => e
    { status_code: 400, error: e.message }
  end

  def elem_to_val(node)
    children = node.elements.to_a
    return (node.text || '').strip if children.empty?

    out = {}
    children.each do |child|
      val = elem_to_val(child)
      tag = child.name
      if out.key?(tag)
        out[tag] = [out[tag]] unless out[tag].is_a?(Array)
        out[tag] << val
      else
        out[tag] = val
      end
    end
    out
  end

  def DictToXml(data, root_tag: 'root')
    doc = REXML::Document.new
    root = doc.add_element(root_tag)
    data.each { |k, v| build_elem(root, v, k) }
    { status_code: 200, text: doc.to_s }
  rescue StandardError => e
    { status_code: 400, error: e.message }
  end

  def build_elem(parent, obj, tag)
    if obj.is_a?(Hash)
      node = parent.add_element(tag)
      obj.each { |k, v| build_elem(node, v, k) }
    elsif obj.is_a?(Array)
      obj.each { |item| build_elem(parent, item, tag) }
    else
      node = parent.add_element(tag)
      node.text = obj.nil? ? '' : obj.to_s
    end
  end
end
