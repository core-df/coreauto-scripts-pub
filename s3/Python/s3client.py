"""
Copyright Core DF

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

S3-compatible object storage helpers (AWS S3, MinIO, etc.).
"""

import os
from typing import Optional

from lib.result import missing_env, transport_error


def _client():
    import boto3

    region = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))
    endpoint = os.environ.get("S3_ENDPOINT_URL", None)
    kwargs = {"region_name": region}
    if endpoint:
        kwargs["endpoint_url"] = endpoint
    return boto3.client("s3", **kwargs)


def _bucket(explicit: Optional[str]) -> str:
    return explicit or os.environ.get("S3_BUCKET", "")


def Init() -> dict:
    if not os.environ.get("AWS_ACCESS_KEY_ID") and not os.environ.get("AWS_PROFILE"):
        return missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
    if not os.environ.get("S3_BUCKET"):
        return missing_env("S3_BUCKET (or pass bucket per call)")
    return {"status_code": 200}


def GetObject(key: str, bucket: Optional[str] = None) -> dict:
    b = _bucket(bucket)
    if not b:
        return missing_env("S3_BUCKET")
    try:
        client = _client()
        resp = client.get_object(Bucket=b, Key=key)
        body = resp["Body"].read()
        try:
            content = body.decode("utf-8")
        except UnicodeDecodeError:
            content = body
        return {"status_code": 200, "content": content}
    except Exception as exc:
        return transport_error(str(exc))


def PutObject(key: str, content: str, bucket: Optional[str] = None) -> dict:
    b = _bucket(bucket)
    if not b:
        return missing_env("S3_BUCKET")
    try:
        client = _client()
        client.put_object(Bucket=b, Key=key, Body=content.encode("utf-8"))
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))


def ListObjects(prefix: str = "", bucket: Optional[str] = None) -> dict:
    b = _bucket(bucket)
    if not b:
        return missing_env("S3_BUCKET")
    try:
        client = _client()
        resp = client.list_objects_v2(Bucket=b, Prefix=prefix)
        keys = [o["Key"] for o in resp.get("Contents", [])]
        return {"status_code": 200, "keys": keys}
    except Exception as exc:
        return transport_error(str(exc))
