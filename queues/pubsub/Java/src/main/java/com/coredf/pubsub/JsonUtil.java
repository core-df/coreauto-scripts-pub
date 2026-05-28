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

package com.coredf.pubsub;

import java.util.Map;

final class JsonUtil {
    private JsonUtil() {}

    static Object parse(String json) {
        if (json == null || json.isBlank()) {
            return null;
        }
        return SimpleJson.parseValue(json.trim(), new int[]{0});
    }

    static String stringify(Object value) {
        return SimpleJson.stringify(value);
    }

    private static final class SimpleJson {
        static Object parseValue(String s, int[] i) {
            skipWs(s, i);
            if (i[0] >= s.length()) {
                return null;
            }
            char c = s.charAt(i[0]);
            if (c == '{') {
                return parseObject(s, i);
            }
            if (c == '[') {
                return parseArray(s, i);
            }
            if (c == '"') {
                return parseString(s, i);
            }
            if (c == 't' && s.startsWith("true", i[0])) {
                i[0] += 4;
                return Boolean.TRUE;
            }
            if (c == 'f' && s.startsWith("false", i[0])) {
                i[0] += 5;
                return Boolean.FALSE;
            }
            if (c == 'n' && s.startsWith("null", i[0])) {
                i[0] += 4;
                return null;
            }
            return parseNumber(s, i);
        }

        static Map<String, Object> parseObject(String s, int[] i) {
            Map<String, Object> map = new java.util.LinkedHashMap<>();
            i[0]++;
            skipWs(s, i);
            if (peek(s, i) == '}') {
                i[0]++;
                return map;
            }
            while (true) {
                skipWs(s, i);
                String key = parseString(s, i);
                skipWs(s, i);
                i[0]++;
                Object val = parseValue(s, i);
                map.put(key, val);
                skipWs(s, i);
                char ch = s.charAt(i[0]++);
                if (ch == '}') {
                    break;
                }
            }
            return map;
        }

        static java.util.List<Object> parseArray(String s, int[] i) {
            java.util.List<Object> list = new java.util.ArrayList<>();
            i[0]++;
            skipWs(s, i);
            if (peek(s, i) == ']') {
                i[0]++;
                return list;
            }
            while (true) {
                list.add(parseValue(s, i));
                skipWs(s, i);
                char ch = s.charAt(i[0]++);
                if (ch == ']') {
                    break;
                }
            }
            return list;
        }

        static String parseString(String s, int[] i) {
            i[0]++;
            StringBuilder sb = new StringBuilder();
            while (i[0] < s.length()) {
                char c = s.charAt(i[0]++);
                if (c == '"') {
                    break;
                }
                if (c == '\\') {
                    char esc = s.charAt(i[0]++);
                    sb.append(switch (esc) {
                        case '"', '\\', '/' -> esc;
                        case 'b' -> '\b';
                        case 'f' -> '\f';
                        case 'n' -> '\n';
                        case 'r' -> '\r';
                        case 't' -> '\t';
                        case 'u' -> (char) Integer.parseInt(s.substring(i[0], i[0] += 4), 16);
                        default -> esc;
                    });
                } else {
                    sb.append(c);
                }
            }
            return sb.toString();
        }

        static Number parseNumber(String s, int[] i) {
            int start = i[0];
            while (i[0] < s.length()) {
                char c = s.charAt(i[0]);
                if (!(Character.isDigit(c) || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E')) {
                    break;
                }
                i[0]++;
            }
            String num = s.substring(start, i[0]);
            if (num.contains(".") || num.contains("e") || num.contains("E")) {
                return Double.valueOf(num);
            }
            return Long.valueOf(num);
        }

        static void skipWs(String s, int[] i) {
            while (i[0] < s.length() && Character.isWhitespace(s.charAt(i[0]))) {
                i[0]++;
            }
        }

        static char peek(String s, int[] i) {
            skipWs(s, i);
            return s.charAt(i[0]);
        }

        static String stringify(Object value) {
            if (value == null) {
                return "null";
            }
            if (value instanceof String s) {
                return '"' + escape(s) + '"';
            }
            if (value instanceof Boolean b) {
                return b ? "true" : "false";
            }
            if (value instanceof Number) {
                return value.toString();
            }
            if (value instanceof Map<?, ?> map) {
                StringBuilder sb = new StringBuilder("{");
                boolean first = true;
                for (Map.Entry<?, ?> e : map.entrySet()) {
                    if (!first) {
                        sb.append(',');
                    }
                    first = false;
                    sb.append(stringify(String.valueOf(e.getKey()))).append(':').append(stringify(e.getValue()));
                }
                return sb.append('}').toString();
            }
            if (value instanceof Iterable<?> it) {
                StringBuilder sb = new StringBuilder("[");
                boolean first = true;
                for (Object o : it) {
                    if (!first) {
                        sb.append(',');
                    }
                    first = false;
                    sb.append(stringify(o));
                }
                return sb.append(']').toString();
            }
            return stringify(String.valueOf(value));
        }

        static String escape(String s) {
            return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r");
        }
    }
}
