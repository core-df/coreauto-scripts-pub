// Copyright Core DF

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

use serde::Serialize;
use serde_json::Value;
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize)]
pub struct Result {
    pub status_code: i32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub payload: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub answer: Option<HashMap<String, Value>>,
}

pub struct Session {
    initialized: bool,
    base_url: String,
    env: String,
    token: String,
}

impl Session {
    pub fn new() -> Self {
        Self {
            initialized: false,
            base_url: String::new(),
            env: String::new(),
            token: String::new(),
        }
    }

    pub fn missing_env(vars: &str) -> Result {
        Result {
            status_code: 601,
            error: Some(Value::String(format!(
                "Environment variables {vars} should be defined"
            ))),
            payload: None,
            answer: None,
        }
    }

    fn trim_url(url: &str) -> String {
        url.trim_matches(|c: char| c == '/' || c.is_whitespace())
            .to_string()
    }

    fn api_error(status_code: i32, body: &str) -> Result {
        match serde_json::from_str::<Value>(body) {
            Ok(v) => Result {
                status_code,
                error: Some(v),
                payload: None,
                answer: None,
            },
            Err(_) => Result {
                status_code,
                error: Some(Value::String("inaccessible".into())),
                payload: None,
                answer: None,
            },
        }
    }

    fn request(&self, method: &str, url: &str, body: Option<&str>) -> std::result::Result<(u16, String), ()> {
        let mut req = match method {
            "GET" => ureq::get(url),
            "POST" => ureq::post(url),
            _ => return Err(()),
        };
        req = req
            .set("Content-Type", "application/json")
            .set("Environment", &self.env);
        if !self.token.is_empty() {
            req = req.set("Authorization", &format!("Bearer {}", self.token));
        }
        let resp = if let Some(b) = body {
            req.send_string(b)
        } else {
            req.call()
        };
        match resp {
            Ok(r) => {
                let code = r.status();
                let text = r.into_string().unwrap_or_default();
                Ok((code, text))
            }
            Err(ureq::Error::Status(code, r)) => {
                let text = r.into_string().unwrap_or_default();
                Ok((code, text))
            }
            Err(_) => Err(()),
        }
    }

    pub fn authenticate(&mut self, env: &str, access_code: &str, base_url: &str) -> Result {
        if self.initialized {
            return Result {
                status_code: 602,
                error: Some(Value::String("init already called".into())),
                payload: None,
                answer: None,
            };
        }
        self.env = env.to_string();
        self.base_url = Self::trim_url(base_url);
        let todo = serde_json::json!({ "apiCode": access_code }).to_string();
        let (status_code, body) = match self.request("POST", &format!("{}/v1/auth/apicode", self.base_url), Some(&todo)) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: 0,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        let code = status_code as i32;
        if code >= 400 {
            return Self::api_error(code, &body);
        }
        let parsed: Value = match serde_json::from_str(&body) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: code,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        let token = parsed.get("token").and_then(|v| v.as_str()).unwrap_or("");
        if token.is_empty() {
            return Result {
                status_code: code,
                error: Some(Value::String("inaccessible".into())),
                payload: None,
                answer: None,
            };
        }
        self.token = token.to_string();
        self.initialized = true;
        Result {
            status_code: code,
            error: None,
            payload: None,
            answer: None,
        }
    }

    pub fn get_event_payload(&self, action_id: &str) -> Result {
        if !self.initialized {
            return Result {
                status_code: 603,
                error: Some(Value::String("Init required".into())),
                payload: None,
                answer: None,
            };
        }
        let (status_code, body) = match self.request("GET", &format!("{}/v1/rtevent/{}", self.base_url, action_id), None) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: 0,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        let code = status_code as i32;
        if code >= 400 {
            return Self::api_error(code, &body);
        }
        let parsed: Value = match serde_json::from_str(&body) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: code,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        Result {
            status_code: code,
            error: None,
            payload: parsed.get("payload").cloned(),
            answer: None,
        }
    }

    pub fn put_step_payload(&self, action_id: &str, step_name: &str, payload: Value) -> Result {
        if !self.initialized {
            return Result {
                status_code: 603,
                error: Some(Value::String("Init required".into())),
                payload: None,
                answer: None,
            };
        }
        let todo = serde_json::json!({
            "actionId": action_id,
            "stepname": step_name,
            "payload": payload,
        })
        .to_string();
        let (status_code, body) = match self.request("POST", &format!("{}/v1/rtstep/payload", self.base_url), Some(&todo)) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: 0,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        let code = status_code as i32;
        if code >= 400 {
            return Self::api_error(code, &body);
        }
        Result {
            status_code: code,
            error: None,
            payload: None,
            answer: None,
        }
    }

    pub fn get_step_payload(&self, action_id: &str, step_name: &str) -> Result {
        if !self.initialized {
            return Result {
                status_code: 603,
                error: Some(Value::String("Init required".into())),
                payload: None,
                answer: None,
            };
        }
        let url = format!(
            "{}/v1/rtstep/payload/{}/{}",
            self.base_url, action_id, step_name
        );
        let (status_code, body) = match self.request("GET", &url, None) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: 0,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        let code = status_code as i32;
        if code >= 400 {
            return Self::api_error(code, &body);
        }
        let parsed: Value = match serde_json::from_str(&body) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: code,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        Result {
            status_code: code,
            error: None,
            payload: parsed.get("payload").cloned(),
            answer: None,
        }
    }

    pub fn get_keystore(&self, keylist: &str) -> Result {
        if !self.initialized {
            return Result {
                status_code: 603,
                error: Some(Value::String("Init required".into())),
                payload: None,
                answer: None,
            };
        }
        let keys: String = keylist.chars().filter(|c| *c != ' ').collect();
        let url = format!("{}/v1/keystore/{}", self.base_url, keys);
        let (status_code, body) = match self.request("GET", &url, None) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: 0,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        let code = status_code as i32;
        if code >= 400 {
            return Self::api_error(code, &body);
        }
        let parsed: HashMap<String, Value> = match serde_json::from_str(&body) {
            Ok(v) => v,
            Err(_) => {
                return Result {
                    status_code: code,
                    error: Some(Value::String("inaccessible".into())),
                    payload: None,
                    answer: None,
                }
            }
        };
        for key in keys.split(',') {
            if key.is_empty() {
                continue;
            }
            if !parsed.contains_key(key) {
                return Result {
                    status_code: 605,
                    error: Some(Value::String(format!("{key} not found"))),
                    payload: None,
                    answer: None,
                };
            }
        }
        Result {
            status_code: code,
            error: None,
            payload: None,
            answer: Some(parsed),
        }
    }
}

impl Default for Session {
    fn default() -> Self {
        Self::new()
    }
}
