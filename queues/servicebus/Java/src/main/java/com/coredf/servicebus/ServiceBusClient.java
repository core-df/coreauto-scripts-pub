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

package com.coredf.servicebus;
import com.azure.messaging.servicebus.*; import java.util.*;
public final class ServiceBusClient {
    private ServiceBusClient() {}
    public static Result Init() {
        if (MsgUtil.env("SERVICE_BUS_CONNECTION_STRING").isEmpty()) return Result.missingEnv("SERVICE_BUS_CONNECTION_STRING");
        if (MsgUtil.env("SERVICE_BUS_QUEUE_NAME").isEmpty()) return Result.missingEnv("SERVICE_BUS_QUEUE_NAME (or pass queue per call)");
        return Result.ok();
    }
    public static Result Send(Object value, String queue) {
        String conn = MsgUtil.env("SERVICE_BUS_CONNECTION_STRING"); String q = queue != null ? queue : MsgUtil.env("SERVICE_BUS_QUEUE_NAME");
        if (conn.isEmpty()) return Result.missingEnv("SERVICE_BUS_CONNECTION_STRING");
        if (q.isEmpty()) return Result.missingEnv("SERVICE_BUS_QUEUE_NAME");
        try (ServiceBusClientBuilder b = new ServiceBusClientBuilder().connectionString(conn);
             ServiceBusSenderClient sender = b.sender().queueName(q).buildClient()) {
            sender.sendMessage(new ServiceBusMessage(MsgUtil.encode(value))); return Result.ok();
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Send(Object value) { return Send(value, null); }
    public static Result Receive(String queue, double timeoutSec, int maxMessages, boolean complete) {
        String conn = MsgUtil.env("SERVICE_BUS_CONNECTION_STRING"); String q = queue != null ? queue : MsgUtil.env("SERVICE_BUS_QUEUE_NAME");
        if (conn.isEmpty()) return Result.missingEnv("SERVICE_BUS_CONNECTION_STRING");
        if (q.isEmpty()) return Result.missingEnv("SERVICE_BUS_QUEUE_NAME");
        List<Map<String, Object>> messages = new ArrayList<>();
        try (ServiceBusReceiverClient receiver = new ServiceBusClientBuilder().connectionString(conn).receiver().queueName(q).buildClient()) {
            Iterable<ServiceBusReceivedMessage> batch = receiver.receiveMessages(maxMessages, java.time.Duration.ofSeconds((long)timeoutSec));
            for (ServiceBusReceivedMessage msg : batch) {
                Map<String, Object> m = new LinkedHashMap<>(); m.put("queue", q); m.put("message_id", msg.getMessageId()); m.put("value", MsgUtil.decode(msg.getBody().toBytes()));
                messages.add(m); if (complete) receiver.complete(msg);
            }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
        return Result.ok(Map.of("messages", messages));
    }
    public static Result Receive() { return Receive(null, 30, 1, true); }
}
