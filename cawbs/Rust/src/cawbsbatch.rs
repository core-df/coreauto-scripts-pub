// Copyright (c) Core DF. All rights reserved.
//
// Batch-oriented cawbs client for the Core Auto Collector.
//
// Documentation: https://coreauto.coredf.com/resources

use crate::wbs::{Result, Session};
use std::env;
use std::sync::{Mutex, OnceLock};

fn sess() -> &'static Mutex<Session> {
    static SESS: OnceLock<Mutex<Session>> = OnceLock::new();
    SESS.get_or_init(|| Mutex::new(Session::new()))
}

pub struct CawbsBatch;

impl CawbsBatch {
    pub fn init() -> Result {
        let env = env::var("ENV").unwrap_or_default();
        let access_code = env::var("CA_ACCESS_CODE").unwrap_or_default();
        let base_url = env::var("CA_WBS_URL").unwrap_or_default();
        if env.is_empty() || access_code.is_empty() || base_url.is_empty() {
            return Session::missing_env("ENV, CA_ACCESS_CODE, CA_WBS_URL");
        }
        sess().lock().unwrap().authenticate(&env, &access_code, &base_url)
    }

    pub fn get_keystore(keylist: &str) -> Result {
        sess().lock().unwrap().get_keystore(keylist)
    }
}
