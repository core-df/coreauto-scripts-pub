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

package com.coredf.s3;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.model.*;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.*;

public final class S3Client {
    private S3Client() {}

    private static software.amazon.awssdk.services.s3.S3Client aws() {
        var b = software.amazon.awssdk.services.s3.S3Client.builder()
                .region(Region.of(envOr("AWS_REGION", envOr("AWS_DEFAULT_REGION", "us-east-1"))));
        String endpoint = env("S3_ENDPOINT_URL");
        if (!endpoint.isEmpty()) {
            b.endpointOverride(URI.create(endpoint));
        }
        return b.build();
    }

    private static String bucket(String explicit) {
        return explicit != null && !explicit.isEmpty() ? explicit : env("S3_BUCKET");
    }

    public static Result Init() {
        if (env("AWS_ACCESS_KEY_ID").isEmpty() && env("AWS_PROFILE").isEmpty()) {
            return Result.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
        }
        if (env("S3_BUCKET").isEmpty()) {
            return Result.missingEnv("S3_BUCKET (or pass bucket per call)");
        }
        return Result.ok();
    }

    public static Result GetObject(String key, String bucket) {
        String b = bucket(bucket);
        if (b.isEmpty()) return Result.missingEnv("S3_BUCKET");
        try (var c = aws()) {
            var resp = c.getObject(GetObjectRequest.builder().bucket(b).key(key).build());
            byte[] data = resp.readAllBytes();
            try {
                return Result.ok(Map.of("content", new String(data, StandardCharsets.UTF_8)));
            } catch (Exception e) {
                return Result.ok(Map.of("content", data));
            }
        } catch (Exception e) {
            return Result.transportError(e.getMessage());
        }
    }

    public static Result GetObject(String key) { return GetObject(key, null); }

    public static Result PutObject(String key, String content, String bucket) {
        String b = bucket(bucket);
        if (b.isEmpty()) return Result.missingEnv("S3_BUCKET");
        try (var c = aws()) {
            c.putObject(PutObjectRequest.builder().bucket(b).key(key).build(), RequestBody.fromString(content));
            return Result.ok();
        } catch (Exception e) {
            return Result.transportError(e.getMessage());
        }
    }

    public static Result PutObject(String key, String content) { return PutObject(key, content, null); }

    public static Result ListObjects(String prefix, String bucket) {
        String b = bucket(bucket);
        if (b.isEmpty()) return Result.missingEnv("S3_BUCKET");
        try (var c = aws()) {
            var resp = c.listObjectsV2(ListObjectsV2Request.builder().bucket(b).prefix(prefix == null ? "" : prefix).build());
            List<String> keys = resp.contents().stream().map(S3Object::key).toList();
            return Result.ok(Map.of("keys", keys));
        } catch (Exception e) {
            return Result.transportError(e.getMessage());
        }
    }

    public static Result ListObjects(String prefix) { return ListObjects(prefix, null); }

    private static String env(String k) { String v = System.getenv(k); return v == null ? "" : v; }
    private static String envOr(String k, String d) { String v = System.getenv(k); return v == null || v.isEmpty() ? d : v; }
}
