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
// Amazon SQS helpers for Core Auto. Send from step scripts; Receive for ingress bridges only.

package sqsclient

import (
	"context"
	"encoding/json"
	"os"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sqs"
	"github.com/core-df/coreauto-scripts-pub/queues/sqs/Go/internal/result"
)

func awsClient(ctx context.Context) (*sqs.Client, error) {
	region := os.Getenv("AWS_REGION")
	if region == "" {
		region = os.Getenv("AWS_DEFAULT_REGION")
	}
	if region == "" {
		region = "us-east-1"
	}
	cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion(region))
	if err != nil {
		return nil, err
	}
	endpoint := os.Getenv("SQS_ENDPOINT_URL")
	if endpoint != "" {
		return sqs.NewFromConfig(cfg, func(o *sqs.Options) {
			o.BaseEndpoint = aws.String(endpoint)
		}), nil
	}
	return sqs.NewFromConfig(cfg), nil
}

func queueURL(explicit string) string {
	if explicit != "" {
		return explicit
	}
	return os.Getenv("SQS_QUEUE_URL")
}

func encode(value any) string {
	switch v := value.(type) {
	case string:
		return v
	default:
		b, _ := json.Marshal(value)
		return string(b)
	}
}

func decode(raw string) any {
	var body any
	if err := json.Unmarshal([]byte(raw), &body); err == nil {
		return body
	}
	return raw
}

// Init verifies AWS credentials and queue URL configuration.
func Init() result.Result {
	if os.Getenv("AWS_ACCESS_KEY_ID") == "" && os.Getenv("AWS_PROFILE") == "" {
		return result.MissingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
	}
	if os.Getenv("SQS_QUEUE_URL") == "" {
		return result.MissingEnv("SQS_QUEUE_URL (or pass queue_url per call)")
	}
	return result.Result{StatusCode: 200}
}

// Send publishes a message to SQS.
func Send(value any, queueURLParam string) result.Result {
	url := queueURL(queueURLParam)
	if url == "" {
		return result.MissingEnv("SQS_QUEUE_URL")
	}
	ctx := context.Background()
	client, err := awsClient(ctx)
	if err != nil {
		return result.TransportError(err.Error())
	}
	resp, err := client.SendMessage(ctx, &sqs.SendMessageInput{
		QueueUrl:    aws.String(url),
		MessageBody: aws.String(encode(value)),
	})
	if err != nil {
		return result.TransportError(err.Error())
	}
	msgID := ""
	if resp.MessageId != nil {
		msgID = *resp.MessageId
	}
	return result.Result{StatusCode: 200, MessageID: msgID}
}

// Receive long-polls messages from SQS (ingress bridges only).
func Receive(queueURLParam string, maxMessages int, waitTimeSec int, delete bool) result.Result {
	url := queueURL(queueURLParam)
	if url == "" {
		return result.MissingEnv("SQS_QUEUE_URL")
	}
	if maxMessages < 1 {
		maxMessages = 1
	}
	if maxMessages > 10 {
		maxMessages = 10
	}
	ctx := context.Background()
	client, err := awsClient(ctx)
	if err != nil {
		return result.TransportError(err.Error())
	}
	resp, err := client.ReceiveMessage(ctx, &sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(url),
		MaxNumberOfMessages: int32(maxMessages),
		WaitTimeSeconds:     int32(waitTimeSec),
	})
	if err != nil {
		return result.TransportError(err.Error())
	}
	messages := make([]map[string]any, 0, len(resp.Messages))
	for _, item := range resp.Messages {
		entry := map[string]any{
			"message_id": aws.ToString(item.MessageId),
			"value":      decode(aws.ToString(item.Body)),
		}
		if item.ReceiptHandle != nil {
			entry["receipt_handle"] = *item.ReceiptHandle
		}
		messages = append(messages, entry)
		if delete && item.ReceiptHandle != nil {
			_, err := client.DeleteMessage(ctx, &sqs.DeleteMessageInput{
				QueueUrl:      aws.String(url),
				ReceiptHandle: item.ReceiptHandle,
			})
			if err != nil {
				return result.TransportError(err.Error())
			}
		}
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
