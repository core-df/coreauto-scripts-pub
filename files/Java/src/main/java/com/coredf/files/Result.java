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

package com.coredf.files;
import java.util.LinkedHashMap; import java.util.Map;
public final class Result {
  private final int statusCode; private final Map<String, Object> fields;
  public Result(int statusCode, Map<String, Object> fields) { this.statusCode = statusCode; this.fields = fields != null ? fields : Map.of(); }
  public int getStatusCode() { return statusCode; }
  public Object get(String key) { return fields.get(key); }
  public Map<String, Object> getFields() { return fields; }
  public static Result ok() { return new Result(200, new LinkedHashMap<>()); }
  public static Result ok(Map<String, Object> fields) { return new Result(200, new LinkedHashMap<>(fields)); }
  public static Result error(int statusCode, Object error) { Map<String, Object> m = new LinkedHashMap<>(); m.put("error", error); return new Result(statusCode, m); }
  public static Result missingEnv(String vars) { return error(601, "Environment variables " + vars + " should be defined"); }
  public static Result transportError(String message) { return error(0, message != null ? message : "inaccessible"); }
  public Map<String, Object> toMap() { Map<String, Object> m = new LinkedHashMap<>(); m.put("status_code", statusCode); m.putAll(fields); return m; }
}
