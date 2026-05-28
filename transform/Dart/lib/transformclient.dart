// Copyright Core DF — Apache License 2.0
import 'dart:convert';

class Transformclient {
  static Map<String, dynamic> JsonParse(String text) {
    try {
      return {'status_code': 200, 'data': jsonDecode(text)};
    } catch (e) {
      return {'status_code': 400, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> JsonStringify(Object data, {int? indent}) {
    try {
      final enc = indent != null ? JsonEncoder.withIndent(' ' * indent) : jsonEncode;
      final text = indent != null ? (enc as JsonEncoder).convert(data) : jsonEncode(data);
      return {'status_code': 200, 'text': text};
    } catch (e) {
      return {'status_code': 400, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> CsvToRows(String text, {String delimiter = ','}) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return {'status_code': 400, 'error': 'empty csv'};
    final headers = lines.first.split(delimiter);
    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final vals = lines[i].split(delimiter);
      rows.add({for (var j = 0; j < headers.length; j++) headers[j]: j < vals.length ? vals[j] : ''});
    }
    return {'status_code': 200, 'rows': rows};
  }

  static Map<String, dynamic> RowsToCsv(List<Map<String, dynamic>> rows, {String delimiter = ','}) {
    if (rows.isEmpty) return {'status_code': 400, 'error': 'rows must not be empty'};
    final keys = rows.first.keys.toList();
    final buf = StringBuffer()..writeln(keys.join(delimiter));
    for (final r in rows) {
      buf.writeln(keys.map((k) => '${r[k] ?? ''}').join(delimiter));
    }
    return {'status_code': 200, 'text': buf.toString()};
  }

  static Map<String, dynamic> XmlToDict(String text) {
    try {
      final tag = RegExp(r'<(\w+)').firstMatch(text)?.group(1) ?? 'root';
      return {'status_code': 200, 'data': {tag: {}}};
    } catch (e) {
      return {'status_code': 400, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> DictToXml(Map<String, dynamic> data, {String rootTag = 'root'}) {
    return {'status_code': 200, 'text': '<$rootTag/>'};
  }
}
