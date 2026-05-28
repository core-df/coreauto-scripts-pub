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

package com.coredf.s3

import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.regions.Region
import software.amazon.awssdk.services.s3.model.GetObjectRequest
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request
import software.amazon.awssdk.services.s3.model.PutObjectRequest
import java.net.URI
import java.nio.charset.StandardCharsets

object S3Client {
    private fun aws(): software.amazon.awssdk.services.s3.S3Client {
        val b = software.amazon.awssdk.services.s3.S3Client.builder()
            .region(Region.of(env("AWS_REGION", env("AWS_DEFAULT_REGION", "us-east-1"))))
        env("S3_ENDPOINT_URL").takeIf { it.isNotEmpty() }?.let { b.endpointOverride(URI.create(it)) }
        return b.build()
    }

    private fun bucket(explicit: String?): String =
        if (!explicit.isNullOrEmpty()) explicit else env("S3_BUCKET")

    @JvmStatic
    fun Init(): Result {
        if (env("AWS_ACCESS_KEY_ID").isEmpty() && env("AWS_PROFILE").isEmpty()) {
            return Result.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
        }
        if (env("S3_BUCKET").isEmpty()) return Result.missingEnv("S3_BUCKET (or pass bucket per call)")
        return Result.ok()
    }

    @JvmStatic
    fun GetObject(key: String, bucketName: String? = null): Result {
        val b = bucket(bucketName)
        if (b.isEmpty()) return Result.missingEnv("S3_BUCKET")
        return try {
            aws().use { c ->
                val data = c.getObject(GetObjectRequest.builder().bucket(b).key(key).build()).readAllBytes()
                Result.ok(mapOf("content" to String(data, StandardCharsets.UTF_8)))
            }
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    @JvmStatic
    fun PutObject(key: String, content: String, bucketName: String? = null): Result {
        val b = bucket(bucketName)
        if (b.isEmpty()) return Result.missingEnv("S3_BUCKET")
        return try {
            aws().use { c ->
                c.putObject(
                    PutObjectRequest.builder().bucket(b).key(key).build(),
                    RequestBody.fromString(content),
                )
                Result.ok()
            }
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    @JvmStatic
    fun ListObjects(prefix: String? = "", bucketName: String? = null): Result {
        val b = bucket(bucketName)
        if (b.isEmpty()) return Result.missingEnv("S3_BUCKET")
        return try {
            aws().use { c ->
                val resp = c.listObjectsV2(
                    ListObjectsV2Request.builder().bucket(b).prefix(prefix ?: "").build(),
                )
                Result.ok(mapOf("keys" to resp.contents().map { it.key() }))
            }
        } catch (e: Exception) {
            Result.transportError(e.message)
        }
    }

    private fun env(k: String): String = System.getenv(k) ?: ""
    private fun env(k: String, d: String): String = env(k).ifEmpty { d }
}
