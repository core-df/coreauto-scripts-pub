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

package com.coredf.ibmmq;
import com.ibm.msg.client.wmq.*; import com.ibm.msg.client.jms.*; import javax.jms.*; import java.util.*;
public final class IbmMqClient {
    private IbmMqClient() {}
    public static Result Init() {
        if (MsgUtil.env("MQ_HOST").isEmpty() || MsgUtil.env("MQ_QUEUE_MANAGER").isEmpty()) return Result.missingEnv("MQ_HOST and MQ_QUEUE_MANAGER");
        if (MsgUtil.env("MQ_QUEUE").isEmpty()) return Result.missingEnv("MQ_QUEUE (or pass queue per call)");
        return Result.ok();
    }
    public static Result Put(Object value, String queue) {
        String q = queue != null ? queue : MsgUtil.env("MQ_QUEUE"); if (q.isEmpty()) return Result.missingEnv("MQ_QUEUE");
        try { send(q, MsgUtil.encode(value)); return Result.ok(); } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Put(Object value) { return Put(value, null); }
    public static Result Get(String queue, double timeoutSec, int maxMessages) {
        String q = queue != null ? queue : MsgUtil.env("MQ_QUEUE"); if (q.isEmpty()) return Result.missingEnv("MQ_QUEUE");
        List<Map<String, Object>> messages = new ArrayList<>();
        try {
            for (int i = 0; i < Math.max(1, maxMessages); i++) {
                byte[] body = receive(q, (long)(timeoutSec * 1000)); if (body == null) break;
                messages.add(Map.of("queue", q, "value", MsgUtil.decode(body)));
            }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
        return Result.ok(Map.of("messages", messages));
    }
    public static Result Get() { return Get(null, 30, 1); }
    private static Connection connect() throws JMSException {
        MQConnectionFactory f = new MQConnectionFactory(); f.setHostName(MsgUtil.env("MQ_HOST"));
        f.setPort(Integer.parseInt(MsgUtil.envOr("MQ_PORT", "1414"))); f.setQueueManager(MsgUtil.env("MQ_QUEUE_MANAGER"));
        f.setChannel(MsgUtil.envOr("MQ_CHANNEL", "SYSTEM.DEF.SVRCONN")); f.setTransportType(WMQConstants.WMQ_CM_CLIENT);
        String user = MsgUtil.env("MQ_USER"); return user.isEmpty() ? f.createConnection() : f.createConnection(user, MsgUtil.env("MQ_PASSWORD"));
    }
    private static void send(String queue, byte[] body) throws JMSException {
        Connection conn = connect(); conn.start(); try (Session s = conn.createSession(false, Session.AUTO_ACKNOWLEDGE)) {
            Queue q = s.createQueue(queue); MessageProducer p = s.createProducer(q); BytesMessage m = s.createBytesMessage(); m.writeBytes(body); p.send(m);
        } finally { conn.close(); }
    }
    private static byte[] receive(String queue, long waitMs) throws JMSException {
        Connection conn = connect(); conn.start(); try (Session s = conn.createSession(false, Session.AUTO_ACKNOWLEDGE)) {
            Queue q = s.createQueue(queue); MessageConsumer c = s.createConsumer(q); Message msg = c.receive(waitMs);
            if (msg == null) return null; if (msg instanceof BytesMessage bm) { byte[] b = new byte[(int)bm.getBodyLength()]; bm.readBytes(b); return b; }
            return msg.toString().getBytes();
        } finally { conn.close(); }
    }
}
