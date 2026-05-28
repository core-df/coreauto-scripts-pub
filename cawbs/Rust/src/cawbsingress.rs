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
//
// Core Auto Web Services — ingress client for the Core Auto Collector.
//
// Use outside step scripts (queue bridges, schedulers, file watchers) to submit
// events and flags that trigger Core Auto real-time or batch workflows.
//
// Documentation: https://coreauto.coredf.com/resources

use crate::wbs::{Result, Session};
use serde_json::Value;
use std::env;
use std::sync::{Mutex, OnceLock};

fn sess() -> &'static Mutex<Session> {
    static SESS: OnceLock<Mutex<Session>> = OnceLock::new();
    SESS.get_or_init(|| Mutex::new(Session::new()))
}

pub struct CawbsIngress;

impl CawbsIngress {
    pub fn init() -> Result {
        let env = env::var("ENV").unwrap_or_default();
        let access_code = env::var("CA_ACCESS_CODE").unwrap_or_default();
        let base_url = env::var("CA_WBS_URL").unwrap_or_default();
        if env.is_empty() || access_code.is_empty() || base_url.is_empty() {
            return Session::missing_env("ENV, CA_ACCESS_CODE, CA_WBS_URL");
        }
        sess().lock().unwrap().authenticate(&env, &access_code, &base_url)
    }

    pub fn post_event(event_name: &str, payload: Value, event_source: Option<&str>) -> Result {
        sess().lock().unwrap().post_event(event_name, payload, event_source)
    }

    pub fn get_event_status(action_id: i64) -> Result {
        sess().lock().unwrap().get_event_status(action_id)
    }

    pub fn get_event_list() -> Result {
        sess().lock().unwrap().get_event_list()
    }

    pub fn submit_flag(name: &str, system_name: &str, source_system_name: &str, date: &str) -> Result {
        sess()
            .lock()
            .unwrap()
            .submit_flag(name, system_name, source_system_name, date)
    }

    pub fn get_keystore(keylist: &str) -> Result {
        sess().lock().unwrap().get_keystore(keylist)
    }
}
