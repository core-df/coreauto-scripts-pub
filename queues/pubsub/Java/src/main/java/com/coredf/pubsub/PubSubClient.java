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

package com.coredf.pubsub;

import com.google.cloud.pubsub.v1.Publisher;
import com.google.cloud.pubsub.v1.SubscriberClient;
import com.google.protobuf.ByteString;
import com.google.pubsub.v1.AcknowledgeRequest;
import com.google.pubsub.v1.ProjectSubscriptionName;
import com.google.pubsub.v1.PubsubMessage;
import com.google.pubsub.v1.PullRequest;
import com.google.pubsub.v1.PullResponse;
import com.google.pubsub.v1.ReceivedMessage;
import com.google.pubsub.v1.TopicName;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

public final class PubSubClient {
    private PubSubClient() {}

    private static String project() {
        return MsgUtil.envOr("PUBSUB_PROJECT_ID", MsgUtil.env("GOOGLE_CLOUD_PROJECT"));
    }

    public static Result Init() {
        if (project().isEmpty()) {
            return Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
        }
        return Result.ok();
    }

    public static Result Publish(Object value, String topic) {
        String project = project();
        String topicId = topic != null ? topic : MsgUtil.env("PUBSUB_TOPIC_ID");
        if (project.isEmpty()) {
            return Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
        }
        if (topicId.isEmpty()) {
            return Result.missingEnv("PUBSUB_TOPIC_ID");
        }
        try (Publisher publisher = Publisher.newBuilder(TopicName.of(project, topicId)).build()) {
            String id = publisher.publish(
                    PubsubMessage.newBuilder().setData(ByteString.copyFrom(MsgUtil.encode(value))).build())
                    .get(30, TimeUnit.SECONDS);
            return Result.ok(Map.of("message_id", id));
        } catch (Exception e) {
            return Result.transportError(e.getMessage());
        }
    }

    public static Result Publish(Object value) {
        return Publish(value, null);
    }

    public static Result Pull(String subscription, int maxMessages, double timeoutSec, boolean ack) {
        String project = project();
        String subId = subscription != null ? subscription : MsgUtil.env("PUBSUB_SUBSCRIPTION_ID");
        if (project.isEmpty()) {
            return Result.missingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
        }
        if (subId.isEmpty()) {
            return Result.missingEnv("PUBSUB_SUBSCRIPTION_ID");
        }
        List<Map<String, Object>> messages = new ArrayList<>();
        List<String> ackIds = new ArrayList<>();
        try (SubscriberClient client = SubscriberClient.create()) {
            String subPath = ProjectSubscriptionName.format(project, subId);
            PullResponse response = client.pull(PullRequest.newBuilder()
                    .setSubscription(subPath)
                    .setMaxMessages(Math.max(1, Math.min(maxMessages, 1000)))
                    .build());
            for (ReceivedMessage rm : response.getReceivedMessagesList()) {
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("subscription", subId);
                m.put("message_id", rm.getMessage().getMessageId());
                m.put("value", MsgUtil.decode(rm.getMessage().getData().toByteArray()));
                messages.add(m);
                ackIds.add(rm.getAckId());
            }
            if (ack && !ackIds.isEmpty()) {
                client.acknowledge(AcknowledgeRequest.newBuilder()
                        .setSubscription(subPath)
                        .addAllAckIds(ackIds)
                        .build());
            }
        } catch (Exception e) {
            return Result.transportError(e.getMessage());
        }
        return Result.ok(Map.of("messages", messages));
    }

    public static Result Pull() {
        return Pull(null, 1, 30, true);
    }
}
