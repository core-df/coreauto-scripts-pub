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
//
// S3-compatible object storage helpers (AWS S3, MinIO, etc.).

package s3client

import (
	"context"
	"io"
	"os"
	"strings"
	"unicode/utf8"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/core-df/coreauto-scripts-pub/s3/Go/internal/result"
)

var awsClientFactory = awsClient

func awsClient(ctx context.Context) (*s3.Client, error) {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "us-east-1"
	}
	opts := []func(*config.LoadOptions) error{
		config.WithRegion(region),
	}
	cfg, err := config.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		return nil, err
	}
	endpoint := os.Getenv("S3_ENDPOINT_URL")
	if endpoint != "" {
		return s3.NewFromConfig(cfg, func(o *s3.Options) {
			o.BaseEndpoint = aws.String(endpoint)
			o.UsePathStyle = true
		}), nil
	}
	return s3.NewFromConfig(cfg), nil
}

func bucket(explicit string) string {
	if explicit != "" {
		return explicit
	}
	return os.Getenv("S3_BUCKET")
}

// Init verifies AWS credentials and default bucket configuration.
func Init() result.Result {
	if os.Getenv("AWS_ACCESS_KEY_ID") == "" && os.Getenv("AWS_PROFILE") == "" {
		return result.MissingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
	}
	if os.Getenv("S3_BUCKET") == "" {
		return result.MissingEnv("S3_BUCKET (or pass bucket per call)")
	}
	return result.Result{StatusCode: 200}
}

// GetObject downloads an object from S3.
func GetObject(key string, bucketName string) result.Result {
	b := bucket(bucketName)
	if b == "" {
		return result.MissingEnv("S3_BUCKET")
	}
	ctx := context.Background()
	client, err := awsClientFactory(ctx)
	if err != nil {
		return result.TransportError(err.Error())
	}
	resp, err := client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(b),
		Key:    aws.String(key),
	})
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return result.TransportError(err.Error())
	}
	content := any(string(body))
	if !isUTF8(body) {
		content = body
	}
	return result.Result{StatusCode: 200, Content: content}
}

// PutObject uploads content to S3.
func PutObject(key string, content string, bucketName string) result.Result {
	b := bucket(bucketName)
	if b == "" {
		return result.MissingEnv("S3_BUCKET")
	}
	ctx := context.Background()
	client, err := awsClientFactory(ctx)
	if err != nil {
		return result.TransportError(err.Error())
	}
	_, err = client.PutObject(ctx, &s3.PutObjectInput{
		Bucket: aws.String(b),
		Key:    aws.String(key),
		Body:   strings.NewReader(content),
	})
	if err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// ListObjects lists object keys under an optional prefix.
func ListObjects(prefix string, bucketName string) result.Result {
	b := bucket(bucketName)
	if b == "" {
		return result.MissingEnv("S3_BUCKET")
	}
	ctx := context.Background()
	client, err := awsClientFactory(ctx)
	if err != nil {
		return result.TransportError(err.Error())
	}
	resp, err := client.ListObjectsV2(ctx, &s3.ListObjectsV2Input{
		Bucket: aws.String(b),
		Prefix: aws.String(prefix),
	})
	if err != nil {
		return result.TransportError(err.Error())
	}
	keys := make([]string, 0, len(resp.Contents))
	for _, obj := range resp.Contents {
		if obj.Key != nil {
			keys = append(keys, *obj.Key)
		}
	}
	return result.Result{StatusCode: 200, Keys: keys}
}

func isUTF8(data []byte) bool {
	return utf8.Valid(data)
}
