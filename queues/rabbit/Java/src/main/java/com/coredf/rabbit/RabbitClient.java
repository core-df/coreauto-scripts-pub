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

package com.coredf.rabbit;
import com.rabbitmq.client.*; import java.net.URLEncoder; import java.nio.charset.StandardCharsets; import java.util.*;

public final class RabbitClient {
    private RabbitClient() {}
    private static String url() {
        String u = MsgUtil.env("RABBITMQ_URL"); if (!u.isEmpty()) return u;
        String host = MsgUtil.env("RABBITMQ_HOST"); if (host.isEmpty()) return "";
        return "amqp://" + enc(MsgUtil.envOr("RABBITMQ_USER","guest")) + ":" + enc(MsgUtil.envOr("RABBITMQ_PASSWORD","guest"))
            + "@" + host + ":" + MsgUtil.envOr("RABBITMQ_PORT","5672") + "/" + enc(MsgUtil.envOr("RABBITMQ_VHOST","/"));
    }
    private static String enc(String s) { try { return URLEncoder.encode(s, StandardCharsets.UTF_8); } catch (Exception e) { return s; } }
    public static Result Init() { if (url().isEmpty()) return Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST"); return Result.ok(); }
    public static Result Publish(String queue, Object value, boolean durable) {
        if (url().isEmpty()) return Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST");
        try (Connection conn = factory().newConnection(); Channel ch = conn.createChannel()) {
            ch.queueDeclare(queue, durable, false, false, null); ch.basicPublish("", queue, null, MsgUtil.encode(value)); return Result.ok();
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Publish(String queue, Object value) { return Publish(queue, value, true); }
    public static Result Consume(String queue, double timeoutSec, int maxMessages, boolean autoAck, boolean durable) {
        if (url().isEmpty()) return Result.missingEnv("RABBITMQ_URL or RABBITMQ_HOST");
        List<Map<String, Object>> messages = new ArrayList<>();
        try (Connection conn = factory().newConnection(); Channel ch = conn.createChannel()) {
            ch.queueDeclare(queue, durable, false, false, null);
            long deadline = (long)(timeoutSec * 1000);
            while (messages.size() < maxMessages && deadline > 0) {
                GetResponse resp = ch.basicGet(queue, autoAck); if (resp == null) { Thread.sleep(1000); deadline -= 1000; continue; }
                Map<String, Object> m = new LinkedHashMap<>(); m.put("queue", queue); m.put("delivery_tag", resp.getEnvelope().getDeliveryTag());
                m.put("value", MsgUtil.decode(resp.getBody())); messages.add(m);
            }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
        return Result.ok(Map.of("messages", messages));
    }
    public static Result Consume(String queue) { return Consume(queue, 30, 1, true, true); }
    private static ConnectionFactory factory() { ConnectionFactory f = new ConnectionFactory(); f.setUri(url()); return f; }
}
