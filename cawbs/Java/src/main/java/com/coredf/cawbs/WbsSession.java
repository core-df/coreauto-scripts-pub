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
//
// Shared HTTP helpers for the Core Auto Collector (cawbs) Java client.

package com.coredf.cawbs;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

public final class WbsSession {
    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(60))
            .build();

    private boolean initialized;
    private String baseUrl = "";
    private String env = "";
    private String token = "";

    public static Result missingEnv(String vars) {
        return new Result(601, "Environment variables " + vars + " should be defined", null, null);
    }

    private static String trimUrl(String url) {
        return url.replaceAll("^[/ ]+|[/ ]+$", "");
    }

    private record HttpOutcome(int statusCode, String body, boolean transportError) {}

    private HttpOutcome doRequest(String method, String url, String body) throws IOException, InterruptedException {
        HttpRequest.Builder builder = HttpRequest.newBuilder(URI.create(url))
                .timeout(Duration.ofSeconds(60))
                .header("Content-Type", "application/json")
                .header("Environment", env);
        if (!token.isEmpty()) {
            builder.header("Authorization", "Bearer " + token);
        }
        if (body != null) {
            builder.method(method, HttpRequest.BodyPublishers.ofString(body));
        } else {
            builder.method(method, HttpRequest.BodyPublishers.noBody());
        }
        HttpResponse<String> resp = HTTP.send(builder.build(), HttpResponse.BodyHandlers.ofString());
        return new HttpOutcome(resp.statusCode(), resp.body(), false);
    }

    private HttpOutcome safeRequest(String method, String url, String body) {
        try {
            return doRequest(method, url, body);
        } catch (IOException | InterruptedException e) {
            Thread.currentThread().interrupt();
            return new HttpOutcome(0, null, true);
        }
    }

    private static Result apiError(int statusCode, String body) {
        Object err = JsonUtil.parse(body);
        if (err == null) {
            return new Result(statusCode, "inaccessible", null, null);
        }
        return new Result(statusCode, err, null, null);
    }

    public Result authenticate(String env, String accessCode, String baseUrl) {
        if (initialized) {
            return new Result(602, "init already called", null, null);
        }
        this.env = env;
        this.baseUrl = trimUrl(baseUrl);
        String todo = JsonUtil.stringify(Map.of("apiCode", accessCode));
        HttpOutcome out = safeRequest("POST", this.baseUrl + "/v1/auth/apicode", todo);
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (!(parsed instanceof Map<?, ?> map) || !map.containsKey("token")) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        token = String.valueOf(map.get("token"));
        initialized = true;
        return new Result(out.statusCode(), null, null, null);
    }

    public Result getEventPayload(String actionId) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        HttpOutcome out = safeRequest("GET", baseUrl + "/v1/rtevent/" + actionId, null);
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (!(parsed instanceof Map<?, ?> map)) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        return new Result(out.statusCode(), null, map.get("payload"), null);
    }

    public Result putStepPayload(String actionId, String stepName, Object payload) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        Map<String, Object> todo = new LinkedHashMap<>();
        todo.put("actionId", actionId);
        todo.put("stepname", stepName);
        todo.put("payload", payload);
        HttpOutcome out = safeRequest("POST", baseUrl + "/v1/rtstep/payload", JsonUtil.stringify(todo));
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        return new Result(out.statusCode(), null, null, null);
    }

    public Result getStepPayload(String actionId, String stepName) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        HttpOutcome out = safeRequest(
                "GET",
                baseUrl + "/v1/rtstep/payload/" + actionId + "/" + stepName,
                null);
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (!(parsed instanceof Map<?, ?> map)) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        return new Result(out.statusCode(), null, map.get("payload"), null);
    }

    public Result postEvent(String eventName, Object payload, String eventSource) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("eventName", eventName);
        body.put("payload", payload);
        if (eventSource != null) {
            body.put("eventSource", eventSource);
        }
        HttpOutcome out = safeRequest("POST", baseUrl + "/v1/rtevent", JsonUtil.stringify(body));
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (!(parsed instanceof Map<?, ?> map)) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        Map<String, Object> resultPayload = new LinkedHashMap<>();
        if (map.containsKey("eventId")) {
            resultPayload.put("eventId", map.get("eventId"));
        }
        if (map.containsKey("actionId")) {
            resultPayload.put("actionId", map.get("actionId"));
        }
        if (map.containsKey("createdAt")) {
            resultPayload.put("createdAt", map.get("createdAt"));
        }
        return new Result(out.statusCode(), null, resultPayload, null);
    }

    public Result getEventStatus(String actionId) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        HttpOutcome out = safeRequest("GET", baseUrl + "/v1/rtevent/status/" + actionId, null);
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (parsed == null) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        return new Result(out.statusCode(), null, parsed, null);
    }

    public Result getEventList() {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        HttpOutcome out = safeRequest("GET", baseUrl + "/v1/rtevent/list", null);
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (parsed == null) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        return new Result(out.statusCode(), null, parsed, null);
    }

    public Result submitFlag(String name, String systemName, String sourceSystemName, String date) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("name", name);
        body.put("systemName", systemName);
        body.put("sourceSystemName", sourceSystemName);
        body.put("date", date);
        HttpOutcome out = safeRequest("POST", baseUrl + "/v1/flag", JsonUtil.stringify(body));
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (!(parsed instanceof Map<?, ?> map)) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        Map<String, Object> resultPayload = new LinkedHashMap<>();
        if (map.containsKey("status")) {
            resultPayload.put("flagStatus", map.get("status"));
        }
        return new Result(out.statusCode(), null, resultPayload, null);
    }

    @SuppressWarnings("unchecked")
    public Result getKeystore(String keylist) {
        if (!initialized) {
            return new Result(603, "Init required", null, null);
        }
        String keys = keylist.replace(" ", "");
        HttpOutcome out = safeRequest("GET", baseUrl + "/v1/keystore/" + keys, null);
        if (out.transportError()) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        if (out.statusCode() >= 400) {
            return apiError(out.statusCode(), out.body());
        }
        Object parsed = JsonUtil.parse(out.body());
        if (!(parsed instanceof Map<?, ?> map)) {
            return new Result(out.statusCode(), "inaccessible", null, null);
        }
        for (String key : keys.split(",")) {
            if (key.isEmpty()) {
                continue;
            }
            if (!map.containsKey(key)) {
                return new Result(605, key + " not found", null, null);
            }
        }
        return new Result(out.statusCode(), null, null, (Map<String, Object>) map);
    }
}
