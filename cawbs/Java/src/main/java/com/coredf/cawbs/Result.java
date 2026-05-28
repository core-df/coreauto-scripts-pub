// Copyright (c) Core DF. All rights reserved.

package com.coredf.cawbs;

import java.util.LinkedHashMap;
import java.util.Map;

public final class Result {
    private final int statusCode;
    private final Object error;
    private final Object payload;
    private final Map<String, Object> answer;

    public Result(int statusCode, Object error, Object payload, Map<String, Object> answer) {
        this.statusCode = statusCode;
        this.error = error;
        this.payload = payload;
        this.answer = answer;
    }

    public int getStatusCode() {
        return statusCode;
    }

    public Object getError() {
        return error;
    }

    public Object getPayload() {
        return payload;
    }

    public Map<String, Object> getAnswer() {
        return answer;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("status_code", statusCode);
        if (error != null) {
            m.put("error", error);
        }
        if (payload != null) {
            m.put("payload", payload);
        }
        if (answer != null) {
            m.put("answer", answer);
        }
        return m;
    }
}
