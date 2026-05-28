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
// Notification helpers: Slack, Microsoft Teams, email, PagerDuty.

package notifyclient

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/smtp"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/core-df/coreauto-scripts-pub/notify/Go/internal/result"
)

const httpTimeout = 30 * time.Second

var notifyHTTP = &http.Client{Timeout: httpTimeout}

// Slack sends a message to a Slack incoming webhook.
func Slack(text string, webhookURL string) result.Result {
	url := webhookURL
	if url == "" {
		url = os.Getenv("SLACK_WEBHOOK_URL")
	}
	if url == "" {
		return result.MissingEnv("SLACK_WEBHOOK_URL")
	}
	body, _ := json.Marshal(map[string]string{"text": text})
	return postJSON(url, body)
}

// Teams sends a message to a Microsoft Teams incoming webhook.
func Teams(text string, webhookURL string) result.Result {
	url := webhookURL
	if url == "" {
		url = os.Getenv("TEAMS_WEBHOOK_URL")
	}
	if url == "" {
		return result.MissingEnv("TEAMS_WEBHOOK_URL")
	}
	payload := map[string]string{
		"@type":    "MessageCard",
		"@context": "http://schema.org/extensions",
		"text":     text,
	}
	body, _ := json.Marshal(payload)
	return postJSON(url, body)
}

// Email sends a plain-text email via SMTP.
func Email(subject, body, toAddrs, fromAddr string) result.Result {
	host := os.Getenv("SMTP_HOST")
	portStr := os.Getenv("SMTP_PORT")
	user := os.Getenv("SMTP_USER")
	password := os.Getenv("SMTP_PASSWORD")
	sender := fromAddr
	if sender == "" {
		sender = os.Getenv("SMTP_FROM")
	}
	if sender == "" {
		sender = user
	}
	if host == "" || sender == "" {
		return result.MissingEnv("SMTP_HOST and SMTP_FROM (or from_addr)")
	}
	port := 587
	if portStr != "" {
		p, err := strconv.Atoi(portStr)
		if err != nil {
			return result.TransportError(err.Error())
		}
		port = p
	}

	msg := fmt.Sprintf("From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s",
		sender, toAddrs, subject, body)

	recipients := splitAddrs(toAddrs)
	addr := fmt.Sprintf("%s:%d", host, port)

	client, err := smtp.Dial(addr)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer client.Close()

	if user != "" && password != "" {
		if ok, _ := client.Extension("STARTTLS"); ok {
			if err := client.StartTLS(&tls.Config{ServerName: host}); err != nil {
				return result.TransportError(err.Error())
			}
		}
		auth := smtp.PlainAuth("", user, password, host)
		if err := client.Auth(auth); err != nil {
			return result.TransportError(err.Error())
		}
	}
	if err := client.Mail(sender); err != nil {
		return result.TransportError(err.Error())
	}
	for _, rcpt := range recipients {
		if err := client.Rcpt(rcpt); err != nil {
			return result.TransportError(err.Error())
		}
	}
	w, err := client.Data()
	if err != nil {
		return result.TransportError(err.Error())
	}
	if _, err := w.Write([]byte(msg)); err != nil {
		return result.TransportError(err.Error())
	}
	if err := w.Close(); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// PagerDuty triggers a PagerDuty event.
func PagerDuty(summary string, routingKey string, severity string) result.Result {
	key := routingKey
	if key == "" {
		key = os.Getenv("PAGERDUTY_ROUTING_KEY")
	}
	if key == "" {
		return result.MissingEnv("PAGERDUTY_ROUTING_KEY")
	}
	if severity == "" {
		severity = "error"
	}
	payload := map[string]any{
		"routing_key":  key,
		"event_action": "trigger",
		"payload": map[string]string{
			"summary":  summary,
			"severity": severity,
			"source":   "coreauto-step",
		},
	}
	body, _ := json.Marshal(payload)
	req, err := http.NewRequest(http.MethodPost, "https://events.pagerduty.com/v2/enqueue", bytes.NewReader(body))
	if err != nil {
		return result.TransportError(err.Error())
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := notifyHTTP.Do(req)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return result.Result{StatusCode: resp.StatusCode, Error: string(respBody)}
	}
	var parsed any
	if err := json.Unmarshal(respBody, &parsed); err == nil {
		return result.Result{StatusCode: 200, Body: parsed}
	}
	return result.Result{StatusCode: 200, Body: string(respBody)}
}

func postJSON(url string, body []byte) result.Result {
	req, err := http.NewRequest(http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return result.TransportError(err.Error())
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := notifyHTTP.Do(req)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return result.Result{StatusCode: resp.StatusCode, Error: string(respBody)}
	}
	return result.Result{StatusCode: 200}
}

func splitAddrs(addrs string) []string {
	parts := strings.Split(addrs, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
