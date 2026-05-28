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

using Amazon;
using Amazon.S3;
using Amazon.S3.Model;

namespace CoreAuto.S3;

public static class S3Client
{
    public static Result Init()
    {
        if (string.IsNullOrEmpty(Env("AWS_ACCESS_KEY_ID")) && string.IsNullOrEmpty(Env("AWS_PROFILE")))
            return Result.MissingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
        if (string.IsNullOrEmpty(Env("S3_BUCKET"))) return Result.MissingEnv("S3_BUCKET (or pass bucket per call)");
        return Result.Ok();
    }

    public static async Task<Result> GetObjectAsync(string key, string? bucket = null)
    {
        var b = Bucket(bucket); if (string.IsNullOrEmpty(b)) return Result.MissingEnv("S3_BUCKET");
        try {
            using var c = Client();
            var resp = await c.GetObjectAsync(b, key);
            using var reader = new StreamReader(resp.ResponseStream);
            return Result.Ok(new() { ["content"] = await reader.ReadToEndAsync() });
        } catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    public static async Task<Result> PutObjectAsync(string key, string content, string? bucket = null)
    {
        var b = Bucket(bucket); if (string.IsNullOrEmpty(b)) return Result.MissingEnv("S3_BUCKET");
        try { using var c = Client(); await c.PutObjectAsync(new PutObjectRequest { BucketName = b, Key = key, ContentBody = content }); return Result.Ok(); }
        catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    public static async Task<Result> ListObjectsAsync(string prefix = "", string? bucket = null)
    {
        var b = Bucket(bucket); if (string.IsNullOrEmpty(b)) return Result.MissingEnv("S3_BUCKET");
        try {
            using var c = Client();
            var resp = await c.ListObjectsV2Async(new ListObjectsV2Request { BucketName = b, Prefix = prefix });
            return Result.Ok(new() { ["keys"] = resp.S3Objects.Select(o => o.Key).ToList() });
        } catch (Exception ex) { return Result.TransportError(ex.Message); }
    }

    private static AmazonS3Client Client()
    {
        var cfg = new AmazonS3Config { RegionEndpoint = RegionEndpoint.GetBySystemName(Env("AWS_REGION", Env("AWS_DEFAULT_REGION", "us-east-1"))) };
        var ep = Env("S3_ENDPOINT_URL"); if (!string.IsNullOrEmpty(ep)) cfg.ServiceURL = ep;
        return new AmazonS3Client(cfg);
    }

    private static string Bucket(string? explicitBucket) => string.IsNullOrEmpty(explicitBucket) ? Env("S3_BUCKET") : explicitBucket;
    private static string Env(string k, string d = "") => Environment.GetEnvironmentVariable(k) ?? d;
}
