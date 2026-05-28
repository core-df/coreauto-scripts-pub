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

use crate::result::{missing_env, transport_error};
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::Client;
use serde_json::{json, Value};
use std::env;
use std::str;

fn region() -> String {
    env::var("AWS_REGION")
        .or_else(|_| env::var("AWS_DEFAULT_REGION"))
        .unwrap_or_else(|_| "us-east-1".into())
}

fn bucket(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("S3_BUCKET").ok())
        .unwrap_or_default()
}

async fn aws_client() -> Result<Client, String> {
    let shared = aws_config::defaults(aws_config::BehaviorVersion::latest())
        .region(aws_config::Region::new(region()))
        .load()
        .await;
    let mut s3_builder = aws_sdk_s3::config::Builder::from(&shared);
    if let Ok(endpoint) = env::var("S3_ENDPOINT_URL") {
        if !endpoint.is_empty() {
            s3_builder = s3_builder
                .endpoint_url(endpoint)
                .force_path_style(true);
        }
    }
    Ok(Client::from_conf(s3_builder.build()))
}

fn block_on<F: std::future::Future<Output = Value>>(f: F) -> Value {
    match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt.block_on(f),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn init() -> Value {
    if env::var("AWS_ACCESS_KEY_ID").unwrap_or_default().is_empty()
        && env::var("AWS_PROFILE").unwrap_or_default().is_empty()
    {
        return missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
    }
    if env::var("S3_BUCKET").unwrap_or_default().is_empty() {
        return missing_env("S3_BUCKET (or pass bucket per call)");
    }
    json!({ "status_code": 200 })
}

pub fn get_object(key: &str, bucket_name: Option<&str>) -> Value {
    let b = bucket(bucket_name);
    if b.is_empty() {
        return missing_env("S3_BUCKET");
    }
    block_on(async move {
        let client = match aws_client().await {
            Ok(c) => c,
            Err(e) => return transport_error(&e),
        };
        let resp = match client.get_object().bucket(&b).key(key).send().await {
            Ok(r) => r,
            Err(e) => return transport_error(&e.to_string()),
        };
        let data = match resp.body.collect().await {
            Ok(b) => b.into_bytes().to_vec(),
            Err(e) => return transport_error(&e.to_string()),
        };
        let content: Value = match str::from_utf8(&data) {
            Ok(s) => Value::String(s.to_string()),
            Err(_) => json!(data),
        };
        json!({ "status_code": 200, "content": content })
    })
}

pub fn put_object(key: &str, content: &str, bucket_name: Option<&str>) -> Value {
    let b = bucket(bucket_name);
    if b.is_empty() {
        return missing_env("S3_BUCKET");
    }
    block_on(async move {
        let client = match aws_client().await {
            Ok(c) => c,
            Err(e) => return transport_error(&e),
        };
        match client
            .put_object()
            .bucket(&b)
            .key(key)
            .body(ByteStream::from(content.as_bytes().to_vec()))
            .send()
            .await
        {
            Ok(_) => json!({ "status_code": 200 }),
            Err(e) => transport_error(&e.to_string()),
        }
    })
}

pub fn list_objects(prefix: &str, bucket_name: Option<&str>) -> Value {
    let b = bucket(bucket_name);
    if b.is_empty() {
        return missing_env("S3_BUCKET");
    }
    let prefix = prefix.to_string();
    block_on(async move {
        let client = match aws_client().await {
            Ok(c) => c,
            Err(e) => return transport_error(&e),
        };
        let resp = match client
            .list_objects_v2()
            .bucket(&b)
            .prefix(&prefix)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => return transport_error(&e.to_string()),
        };
        let keys: Vec<String> = resp
            .contents()
            .iter()
            .filter_map(|o| o.key().map(str::to_string))
            .collect();
        json!({ "status_code": 200, "keys": keys })
    })
}
