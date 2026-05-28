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

using System.Text;
using System.Text.Json;
using System.Xml.Linq;

namespace CoreAuto.Transform;

public static class TransformClient
{
    public static Result JsonParse(string text)
    {
        try { return Result.Ok(new() { ["data"] = JsonSerializer.Deserialize<object>(text)! }); }
        catch (Exception ex) { return Result.Error(400, ex.Message); }
    }

    public static Result JsonStringify(object? data, int? indent = null)
    {
        try {
            var opts = indent.HasValue ? new JsonSerializerOptions { WriteIndented = true } : null;
            return Result.Ok(new() { ["text"] = JsonSerializer.Serialize(data, opts) });
        } catch (Exception ex) { return Result.Error(400, ex.Message); }
    }

    public static Result CsvToRows(string text, string delimiter = ",")
    {
        try {
            var lines = text.Split('
', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
            if (lines.Length == 0) return Result.Ok(new() { ["rows"] = Array.Empty<Dictionary<string, string>>() });
            var headers = lines[0].Split(delimiter);
            var rows = lines.Skip(1).Select(line => {
                var cols = line.Split(delimiter);
                return headers.Select((h, i) => (h, cols.ElementAtOrDefault(i) ?? "")).ToDictionary(x => x.h, x => x.Item2);
            }).ToList();
            return Result.Ok(new() { ["rows"] = rows });
        } catch (Exception ex) { return Result.Error(400, ex.Message); }
    }

    public static Result RowsToCsv(IList<Dictionary<string, string>> rows, string delimiter = ",")
    {
        if (rows.Count == 0) return Result.Error(400, "rows must not be empty");
        var headers = rows[0].Keys.ToList();
        var sb = new StringBuilder(string.Join(delimiter, headers)).Append('
');
        foreach (var row in rows) sb.AppendLine(string.Join(delimiter, headers.Select(h => row.GetValueOrDefault(h, ""))));
        return Result.Ok(new() { ["text"] = sb.ToString() });
    }

    public static Result XmlToDict(string text)
    {
        try { var root = XDocument.Parse(text).Root!; return Result.Ok(new() { ["data"] = new Dictionary<string, object?> { [root.Name.LocalName] = Elem(root) } }); }
        catch (Exception ex) { return Result.Error(400, ex.Message); }
    }

    public static Result DictToXml(Dictionary<string, object?> data, string rootTag = "root")
    {
        try {
            var root = new XElement(rootTag);
            foreach (var (k, v) in data) Build(root, v, k);
            return Result.Ok(new() { ["text"] = root.ToString(SaveOptions.DisableFormatting) });
        } catch (Exception ex) { return Result.Error(400, ex.Message); }
    }

    private static object? Elem(XElement node) {
        if (!node.HasElements) return node.Value.Trim();
        var map = new Dictionary<string, object?>();
        foreach (var child in node.Elements()) {
            var val = Elem(child);
            if (map.TryGetValue(child.Name.LocalName, out var prev)) {
                if (prev is List<object?> list) list.Add(val);
                else map[child.Name.LocalName] = new List<object?> { prev, val };
            } else map[child.Name.LocalName] = val;
        }
        return map;
    }

    private static void Build(XElement parent, object? obj, string tag) {
        if (obj is Dictionary<string, object?> dict) {
            var node = new XElement(tag); parent.Add(node);
            foreach (var (k, v) in dict) Build(node, v, k);
        } else if (obj is IEnumerable<object?> list && obj is not string) {
            foreach (var item in list) parent.Add(new XElement(tag, item?.ToString() ?? ""));
        } else parent.Add(new XElement(tag, obj?.ToString() ?? ""));
    }
}
