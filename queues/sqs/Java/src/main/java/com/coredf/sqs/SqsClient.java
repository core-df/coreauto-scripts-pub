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

package com.coredf.sqs;
import software.amazon.awssdk.regions.Region; import software.amazon.awssdk.services.sqs.SqsClient; import software.amazon.awssdk.services.sqs.model.*;
import java.net.URI; import java.util.*;

public final class SqsClient {
    private SqsClient() {}
    private static SqsClient client() {
        var b = SqsClient.builder().region(Region.of(MsgUtil.envOr("AWS_REGION", MsgUtil.envOr("AWS_DEFAULT_REGION", "us-east-1"))));
        String ep = MsgUtil.env("SQS_ENDPOINT_URL"); if (!ep.isEmpty()) b.endpointOverride(URI.create(ep)); return b.build();
    }
    private static String queue(String explicit) { return explicit != null && !explicit.isEmpty() ? explicit : MsgUtil.env("SQS_QUEUE_URL"); }
    public static Result Init() {
        if (MsgUtil.env("AWS_ACCESS_KEY_ID").isEmpty() && MsgUtil.env("AWS_PROFILE").isEmpty()) return Result.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
        if (MsgUtil.env("SQS_QUEUE_URL").isEmpty()) return Result.missingEnv("SQS_QUEUE_URL (or pass queue_url per call)");
        return Result.ok();
    }
    public static Result Send(Object value, String queueUrl) {
        String url = queue(queueUrl); if (url.isEmpty()) return Result.missingEnv("SQS_QUEUE_URL");
        try (SqsClient c = client()) {
            String body = value instanceof String s ? s : JsonUtil.stringify(value);
            var resp = c.sendMessage(SendMessageRequest.builder().queueUrl(url).messageBody(body).build());
            return Result.ok(Map.of("message_id", resp.messageId()));
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Send(Object value) { return Send(value, null); }
    public static Result Receive(String queueUrl, int maxMessages, int waitTimeSec, boolean delete) {
        String url = queue(queueUrl); if (url.isEmpty()) return Result.missingEnv("SQS_QUEUE_URL");
        maxMessages = Math.max(1, Math.min(maxMessages, 10));
        try (SqsClient c = client()) {
            var resp = c.receiveMessage(ReceiveMessageRequest.builder().queueUrl(url).maxNumberOfMessages(maxMessages).waitTimeSeconds(waitTimeSec).build());
            List<Map<String, Object>> messages = new ArrayList<>();
            for (Message item : resp.messages()) {
                Map<String, Object> m = new LinkedHashMap<>(); m.put("message_id", item.messageId()); m.put("receipt_handle", item.receiptHandle());
                try { m.put("value", JsonUtil.parse(item.body())); } catch (Exception ex) { m.put("value", item.body()); }
                messages.add(m);
                if (delete) c.deleteMessage(DeleteMessageRequest.builder().queueUrl(url).receiptHandle(item.receiptHandle()).build());
            }
            return Result.ok(Map.of("messages", messages));
        } catch (Exception e) { return Result.transportError(e.getMessage()); }
    }
    public static Result Receive() { return Receive(null, 1, 10, true); }
}
