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

package com.coredf.redis;
import java.nio.charset.StandardCharsets;
final class MsgUtil {
    static byte[] encode(Object value) {
        if (value == null) return new byte[0];
        if (value instanceof byte[] b) return b;
        if (value instanceof String s) return s.getBytes(StandardCharsets.UTF_8);
        return JsonUtil.stringify(value).getBytes(StandardCharsets.UTF_8);
    }
    static Object decode(byte[] raw) {
        if (raw == null) return null;
        try { return JsonUtil.parse(new String(raw, StandardCharsets.UTF_8)); }
        catch (Exception e) { return new String(raw, StandardCharsets.UTF_8); }
    }
    static String env(String k) { String v = System.getenv(k); return v == null ? "" : v; }
    static String envOr(String k, String d) { String v = System.getenv(k); return v == null || v.isEmpty() ? d : v; }
}
