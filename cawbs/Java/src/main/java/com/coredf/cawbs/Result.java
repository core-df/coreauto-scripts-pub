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
