// Copyright (c) Core DF. All rights reserved.
//
// Core Auto Web Services library (cawbs) — Rust client for the Core Auto Collector.
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

pub struct Cawbs;

impl Cawbs {
    pub fn init() -> Result {
        let env = env::var("ENV").unwrap_or_default();
        let action_id = env::var("ACTIONID").unwrap_or_default();
        let access_code = env::var("CA_ACCESS_CODE").unwrap_or_default();
        let base_url = env::var("CA_WBS_URL").unwrap_or_default();
        let step_name = env::var("STEPNAME").unwrap_or_default();
        if env.is_empty()
            || action_id.is_empty()
            || access_code.is_empty()
            || base_url.is_empty()
            || step_name.is_empty()
        {
            return Session::missing_env("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME");
        }
        sess().lock().unwrap().authenticate(&env, &access_code, &base_url)
    }

    pub fn get_event_payload() -> Result {
        let action_id = env::var("ACTIONID").unwrap_or_default();
        sess().lock().unwrap().get_event_payload(&action_id)
    }

    pub fn put_step_payload(payload: Value) -> Result {
        let action_id = env::var("ACTIONID").unwrap_or_default();
        let step_name = env::var("STEPNAME").unwrap_or_default();
        sess()
            .lock()
            .unwrap()
            .put_step_payload(&action_id, &step_name, payload)
    }

    pub fn get_step_payload(stepname: &str) -> Result {
        let action_id = env::var("ACTIONID").unwrap_or_default();
        sess().lock().unwrap().get_step_payload(&action_id, stepname)
    }

    pub fn get_keystore(keylist: &str) -> Result {
        sess().lock().unwrap().get_keystore(keylist)
    }
}
