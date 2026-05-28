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

package com.coredf.kafka;
import org.apache.kafka.clients.consumer.*; import org.apache.kafka.clients.producer.*; import org.apache.kafka.common.serialization.*;
import java.time.Duration; import java.util.*; import org.apache.kafka.common.header.internals.RecordHeaders;

public final class KafkaClient {
    private KafkaClient() {}
    private static Properties config(Properties extra) {
        Properties p = new Properties(); p.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, MsgUtil.env("KAFKA_BOOTSTRAP_SERVERS"));
        putIf(p, "security.protocol", MsgUtil.env("KAFKA_SECURITY_PROTOCOL"));
        putIf(p, "sasl.mechanism", MsgUtil.env("KAFKA_SASL_MECHANISM"));
        putIf(p, "sasl.jaas.config", jaas()); putIf(p, "sasl.username", MsgUtil.env("KAFKA_SASL_USERNAME"));
        if (extra != null) p.putAll(extra); return p;
    }
    private static String jaas() {
        String u = MsgUtil.env("KAFKA_SASL_USERNAME"), pw = MsgUtil.env("KAFKA_SASL_PASSWORD");
        if (u.isEmpty()) return ""; return "org.apache.kafka.common.security.plain.PlainLoginModule required username=\"" + u + "\" password=\"" + pw + "\";";
    }
    private static void putIf(Properties p, String k, String v) { if (v != null && !v.isEmpty()) p.put(k, v); }
    public static Result Init() { if (MsgUtil.env("KAFKA_BOOTSTRAP_SERVERS").isEmpty()) return Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS"); return Result.ok(); }
    public static Result Produce(String topic, Object value, String key) {
        if (MsgUtil.env("KAFKA_BOOTSTRAP_SERVERS").isEmpty()) return Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS");
        Properties p = config(null); p.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        p.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, ByteArraySerializer.class.getName());
        try (KafkaProducer<String, byte[]> prod = new KafkaProducer<>(p)) {
            prod.send(new ProducerRecord<>(topic, key, MsgUtil.encode(value))).get(); return Result.ok();
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Produce(String topic, Object value) { return Produce(topic, value, null); }
    public static Result Consume(String topic, double timeoutSec, int maxMessages, String groupId) {
        if (MsgUtil.env("KAFKA_BOOTSTRAP_SERVERS").isEmpty()) return Result.missingEnv("KAFKA_BOOTSTRAP_SERVERS");
        Properties p = config(new Properties()); p.put(ConsumerConfig.GROUP_ID_CONFIG, groupId != null ? groupId : MsgUtil.envOr("KAFKA_GROUP_ID", "coreauto-step"));
        p.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        p.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, ByteArrayDeserializer.class.getName());
        p.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, MsgUtil.envOr("KAFKA_AUTO_OFFSET_RESET", "earliest"));
        List<Map<String, Object>> messages = new ArrayList<>();
        try (KafkaConsumer<String, byte[]> consumer = new KafkaConsumer<>(p)) {
            consumer.subscribe(List.of(topic)); long deadline = (long)(timeoutSec * 1000);
            while (messages.size() < maxMessages && deadline > 0) {
                ConsumerRecords<String, byte[]> recs = consumer.poll(Duration.ofMillis(Math.min(1000, deadline)));
                deadline -= 1000; for (ConsumerRecord<String, byte[]> r : recs) {
                    Map<String, Object> m = new LinkedHashMap<>(); m.put("topic", r.topic()); m.put("partition", r.partition());
                    m.put("offset", r.offset()); m.put("key", r.key()); m.put("value", MsgUtil.decode(r.value())); messages.add(m);
                    if (messages.size() >= maxMessages) break;
                }
            }
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
        return Result.ok(Map.of("messages", messages));
    }
    public static Result Consume(String topic) { return Consume(topic, 30, 1, null); }
}
