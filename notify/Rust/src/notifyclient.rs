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
use serde_json::{json, Value};
use std::env;

fn post_json(url: &str, payload: Value) -> Value {
    let resp = ureq::post(url)
        .set("Content-Type", "application/json")
        .send_json(payload);
    match resp {
        Ok(r) => {
            let code = r.status();
            let text = r.into_string().unwrap_or_default();
            if code >= 400 {
                let body: Value = serde_json::from_str(&text)
                    .unwrap_or_else(|_| Value::String(text));
                return json!({ "status_code": code, "error": body });
            }
            let body: Value = if text.is_empty() {
                Value::Null
            } else {
                serde_json::from_str(&text).unwrap_or_else(|_| Value::String(text))
            };
            if body.is_null() {
                json!({ "status_code": 200 })
            } else {
                json!({ "status_code": 200, "body": body })
            }
        }
        Err(ureq::Error::Status(code, r)) => {
            let text = r.into_string().unwrap_or_default();
            let body: Value = serde_json::from_str(&text)
                .unwrap_or_else(|_| Value::String(text));
            json!({ "status_code": code, "error": body })
        }
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn slack(text: &str, webhook_url: Option<&str>) -> Value {
    let url = webhook_url
        .map(str::to_string)
        .or_else(|| env::var("SLACK_WEBHOOK_URL").ok())
        .filter(|s| !s.is_empty());
    let Some(url) = url else {
        return missing_env("SLACK_WEBHOOK_URL");
    };
    post_json(&url, json!({ "text": text }))
}

pub fn teams(text: &str, webhook_url: Option<&str>) -> Value {
    let url = webhook_url
        .map(str::to_string)
        .or_else(|| env::var("TEAMS_WEBHOOK_URL").ok())
        .filter(|s| !s.is_empty());
    let Some(url) = url else {
        return missing_env("TEAMS_WEBHOOK_URL");
    };
    post_json(
        &url,
        json!({
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "text": text
        }),
    )
}

pub fn pagerduty(summary: &str, routing_key: Option<&str>, severity: Option<&str>) -> Value {
    let key = routing_key
        .map(str::to_string)
        .or_else(|| env::var("PAGERDUTY_ROUTING_KEY").ok())
        .filter(|s| !s.is_empty());
    let Some(key) = key else {
        return missing_env("PAGERDUTY_ROUTING_KEY");
    };
    let sev = severity.unwrap_or("error");
    post_json(
        "https://events.pagerduty.com/v2/enqueue",
        json!({
            "routing_key": key,
            "event_action": "trigger",
            "payload": {
                "summary": summary,
                "severity": sev,
                "source": "coreauto-step"
            }
        }),
    )
}

pub fn email(subject: &str, body: &str, to_addrs: &str, from_addr: Option<&str>) -> Value {
    use std::io::{Read, Write};
    use std::net::TcpStream;

    let host = env::var("SMTP_HOST").unwrap_or_default();
    let port: u16 = env::var("SMTP_PORT")
        .ok()
        .and_then(|p| p.parse().ok())
        .unwrap_or(587);
    let user = env::var("SMTP_USER").unwrap_or_default();
    let password = env::var("SMTP_PASSWORD").unwrap_or_default();
    let sender = from_addr
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("SMTP_FROM").ok())
        .or_else(|| if user.is_empty() { None } else { Some(user.clone()) });

    let Some(sender) = sender.filter(|s| !s.is_empty()) else {
        return missing_env("SMTP_HOST and SMTP_FROM (or from_addr)");
    };
    if host.is_empty() {
        return missing_env("SMTP_HOST and SMTP_FROM (or from_addr)");
    }

    let addr = format!("{host}:{port}");
    let mut stream = match TcpStream::connect(&addr) {
        Ok(s) => s,
        Err(e) => return transport_error(&e.to_string()),
    };
    let mut buf = [0u8; 512];
    let _ = stream.read(&mut buf);

    let send = |s: &mut TcpStream, line: &str| -> bool {
        s.write_all(format!("{line}\r\n").as_bytes()).is_ok()
    };
    let read_ok = |s: &mut TcpStream| -> bool {
        let n = s.read(&mut buf).unwrap_or(0);
        n > 0 && (buf[0] == b'2' || buf[0] == b'3')
    };

    if !send(&mut stream, "EHLO coreauto.local") || !read_ok(&mut stream) {
        return transport_error("smtp handshake failed");
    }
    if !user.is_empty() && !password.is_empty() {
        let _ = send(&mut stream, "STARTTLS");
        let _ = read_ok(&mut stream);
    }
    if !send(&mut stream, &format!("MAIL FROM:<{sender}>")) || !read_ok(&mut stream) {
        return transport_error("smtp mail from failed");
    }
    for to in to_addrs.split(',') {
        let to = to.trim();
        if to.is_empty() {
            continue;
        }
        if !send(&mut stream, &format!("RCPT TO:<{to}>")) || !read_ok(&mut stream) {
            return transport_error("smtp rcpt failed");
        }
    }
    if !send(&mut stream, "DATA") || !read_ok(&mut stream) {
        return transport_error("smtp data failed");
    }
    let msg = format!(
        "From: {sender}\r\nTo: {to_addrs}\r\nSubject: {subject}\r\n\r\n{body}\r\n."
    );
    if stream.write_all(msg.as_bytes()).is_err() || !read_ok(&mut stream) {
        return transport_error("smtp send failed");
    }
    let _ = send(&mut stream, "QUIT");
    json!({ "status_code": 200 })
}
