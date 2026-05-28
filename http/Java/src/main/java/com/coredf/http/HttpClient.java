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
//
// Generic HTTP client helpers for Core Auto step scripts.

package com.coredf.http;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

public final class HttpClient {
    private static final java.net.http.HttpClient HTTP = java.net.http.HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(60))
            .build();

    private HttpClient() {}

    private static Object parseBody(String body) {
        if (body == null || body.isEmpty()) {
            return null;
        }
        String t = body.trim();
        if ((t.startsWith("{") && t.endsWith("}")) || (t.startsWith("[") && t.endsWith("]"))) {
            try {
                return JsonUtil.parse(body);
            } catch (Exception ignored) {
                // fall through to text
            }
        }
        return body;
    }

    private static Result request(
            String method,
            String url,
            Map<String, String> headers,
            String jsonBody,
            Map<String, String> params) {
        try {
            if (params != null && !params.isEmpty()) {
                String qs = params.entrySet().stream()
                        .map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8) + "="
                                + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8))
                        .collect(Collectors.joining("&"));
                url = url + (url.contains("?") ? "&" : "?") + qs;
            }
            Map<String, String> hdrs = headers != null ? new HashMap<>(headers) : new HashMap<>();
            if (jsonBody != null) {
                hdrs.putIfAbsent("Content-Type", "application/json");
            }
            HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofSeconds(60));
            hdrs.forEach(builder::header);
            if (jsonBody != null) {
                builder.method(method, HttpRequest.BodyPublishers.ofString(jsonBody));
            } else {
                builder.method(method, HttpRequest.BodyPublishers.noBody());
            }
            HttpResponse<String> resp = HTTP.send(builder.build(), HttpResponse.BodyHandlers.ofString());
            Object body = parseBody(resp.body());
            if (resp.statusCode() >= 400) {
                return Result.error(resp.statusCode(), body != null ? body : "inaccessible");
            }
            Map<String, Object> fields = new LinkedHashMap<>();
            fields.put("body", body);
            return Result.ok(fields);
        } catch (Exception e) {
            return Result.transportError(e.getMessage());
        }
    }

    public static Result Get(String url, Map<String, String> headers, Map<String, String> params) {
        return request("GET", url, headers, null, params);
    }

    public static Result Get(String url) {
        return Get(url, null, null);
    }

    public static Result Post(String url, Object jsonBody, String data, Map<String, String> headers) {
        String body = data;
        if (jsonBody != null) {
            body = JsonUtil.stringify(jsonBody);
        }
        return request("POST", url, headers, body, null);
    }

    public static Result Post(String url, Object jsonBody) {
        return Post(url, jsonBody, null, null);
    }

    public static Result Put(String url, Object jsonBody, Map<String, String> headers) {
        String body = jsonBody != null ? JsonUtil.stringify(jsonBody) : null;
        return request("PUT", url, headers, body, null);
    }

    public static Result Put(String url, Object jsonBody) {
        return Put(url, jsonBody, null);
    }

    public static Result Delete(String url, Map<String, String> headers) {
        return request("DELETE", url, headers, null, null);
    }

    public static Result Delete(String url) {
        return Delete(url, null);
    }
}
