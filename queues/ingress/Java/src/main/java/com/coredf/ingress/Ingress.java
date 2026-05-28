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

package com.coredf.ingress;

import com.coredf.cawbs.CawbsIngress;

public final class Ingress {
    private Ingress() {}

    public static Result TriggerEvent(Object payload, String eventName, String eventSource) {
        String name = eventName != null ? eventName : env("CA_EVENT_NAME");
        if (name.isEmpty()) {
            return Result.missingEnv("CA_EVENT_NAME (or pass event_name)");
        }
        String source = eventSource != null ? eventSource : env("CA_EVENT_SOURCE");
        com.coredf.cawbs.Result init = CawbsIngress.Init();
        if (init.getStatusCode() >= 400) {
            return fromCawbs(init);
        }
        return fromCawbs(CawbsIngress.PostEvent(name, payload, source.isEmpty() ? null : source));
    }

    public static Result TriggerEvent(Object payload) {
        return TriggerEvent(payload, null, null);
    }

    public static Result ForwardMessages(Result consumeResult) {
        if (consumeResult.getStatusCode() != 200) {
            return consumeResult;
        }
        Object raw = consumeResult.get("messages");
        if (!(raw instanceof Iterable<?> iterable)) {
            return Result.ok(java.util.Map.of("forwarded", java.util.List.of()));
        }
        java.util.List<java.util.Map<String, Object>> forwarded = new java.util.ArrayList<>();
        for (Object item : iterable) {
            Object value = item;
            if (item instanceof java.util.Map<?, ?> map && map.containsKey("value")) {
                value = map.get("value");
            }
            Result posted = TriggerEvent(value);
            if (posted.getStatusCode() >= 400) {
                return posted;
            }
            java.util.Map<String, Object> entry = new java.util.LinkedHashMap<>();
            if (posted.get("actionId") != null) {
                entry.put("actionId", posted.get("actionId"));
            }
            if (posted.get("eventId") != null) {
                entry.put("eventId", posted.get("eventId"));
            }
            forwarded.add(entry);
        }
        return Result.ok(java.util.Map.of("forwarded", forwarded));
    }

    public static Result RunBridge(java.util.function.Supplier<Result> consumeFn) {
        return ForwardMessages(consumeFn.get());
    }

    private static Result fromCawbs(com.coredf.cawbs.Result r) {
        java.util.Map<String, Object> fields = new java.util.LinkedHashMap<>();
        if (r.getAnswer() != null) {
            fields.putAll(r.getAnswer());
        }
        if (r.getError() != null) {
            fields.put("error", r.getError());
        }
        if (r.getPayload() != null) {
            fields.put("payload", r.getPayload());
        }
        return new Result(r.getStatusCode(), fields);
    }

    private static String env(String key) {
        String value = System.getenv(key);
        return value == null ? "" : value;
    }
}
