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
import software.amazon.awssdk.services.s3.model.{GetObjectRequest, ListObjectsV2Request, PutObjectRequest}
import java.net.URI
import java.nio.charset.StandardCharsets

object S3Client:
  private def aws(): software.amazon.awssdk.services.s3.S3Client =
    val b = software.amazon.awssdk.services.s3.S3Client.builder()
      .region(Region.of(env("AWS_REGION", env("AWS_DEFAULT_REGION", "us-east-1"))))
    val endpoint = env("S3_ENDPOINT_URL")
    if endpoint.nonEmpty then b.endpointOverride(URI.create(endpoint))
    b.build()

  private def bucket(explicit: String): String =
    if explicit != null && explicit.nonEmpty then explicit else env("S3_BUCKET")

  def Init(): Result =
    if env("AWS_ACCESS_KEY_ID").isEmpty && env("AWS_PROFILE").isEmpty then
      Result.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
    else if env("S3_BUCKET").isEmpty then Result.missingEnv("S3_BUCKET (or pass bucket per call)")
    else Result.ok()

  def GetObject(key: String, bucketName: String = null): Result =
    val b = bucket(bucketName)
    if b.isEmpty then Result.missingEnv("S3_BUCKET")
    else try
      val c = aws()
      try
        val data = c.getObject(GetObjectRequest.builder().bucket(b).key(key).build()).readAllBytes()
        Result.ok(Map("content" -> new String(data, StandardCharsets.UTF_8)))
      finally c.close()
    catch case e: Exception => Result.transportError(e.getMessage)

  def PutObject(key: String, content: String, bucketName: String = null): Result =
    val b = bucket(bucketName)
    if b.isEmpty then Result.missingEnv("S3_BUCKET")
    else try
      val c = aws()
      try
        c.putObject(PutObjectRequest.builder().bucket(b).key(key).build(), RequestBody.fromString(content))
        Result.ok()
      finally c.close()
    catch case e: Exception => Result.transportError(e.getMessage)

  def ListObjects(prefix: String = "", bucketName: String = null): Result =
    val b = bucket(bucketName)
    if b.isEmpty then Result.missingEnv("S3_BUCKET")
    else try
      val c = aws()
      try
        val resp = c.listObjectsV2(ListObjectsV2Request.builder().bucket(b).prefix(if prefix == null then "" else prefix).build())
        Result.ok(Map("keys" -> resp.contents().stream().map(_.key()).toList))
      finally c.close()
    catch case e: Exception => Result.transportError(e.getMessage)

  private def env(k: String): String = Option(System.getenv(k)).getOrElse("")
  private def env(k: String, d: String): String = val v = env(k); if v.isEmpty then d else v
