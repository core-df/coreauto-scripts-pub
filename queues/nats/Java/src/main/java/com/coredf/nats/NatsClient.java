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

package com.coredf.nats;
import io.nats.client.*; import java.nio.charset.StandardCharsets; import java.time.Duration; import java.util.*;
public final class NatsClient {
    private NatsClient() {}
    private static String servers() { return MsgUtil.envOr("NATS_URL", MsgUtil.env("NATS_SERVERS")); }
    public static Result Init() { if (servers().isEmpty()) return Result.missingEnv("NATS_URL or NATS_SERVERS"); return Result.ok(); }
    public static Result Publish(String subject, Object value) {
        if (servers().isEmpty()) return Result.missingEnv("NATS_URL or NATS_SERVERS");
        try (Connection nc = Nats.connect(servers())) { nc.publish(subject, MsgUtil.encode(value)); nc.flush(Duration.ofSeconds(5)); return Result.ok(); }
        catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Subscribe(String subject, double timeoutSec, int maxMessages) {
        if (servers().isEmpty()) return Result.missingEnv("NATS_URL or NATS_SERVERS");
        List<Map<String, Object>> messages = new ArrayList<>();
        try (Connection nc = Nats.connect(servers())) {
            Dispatcher d = nc.createDispatcher(msg -> {}); Subscription sub = nc.subscribe(subject);
            long deadline = (long)(timeoutSec * 1000);
            while (messages.size() < maxMessages && deadline > 0) {
                Message msg = sub.nextMessage(Duration.ofMillis(Math.min(1000, deadline)));
                deadline -= 1000; if (msg == null) continue;
                messages.add(Map.of("subject", msg.getSubject(), "value", MsgUtil.decode(msg.getData())));
            }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
        return Result.ok(Map.of("messages", messages));
    }
    public static Result Subscribe(String subject) { return Subscribe(subject, 30, 1); }
}
