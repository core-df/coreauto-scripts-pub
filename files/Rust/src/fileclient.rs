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

use serde_json::{json, Value};
use std::fs;
use std::io::Write;
use std::path::Path;

fn io_error(exc: std::io::Error) -> Value {
    json!({
        "status_code": 500,
        "error": exc.to_string()
    })
}

pub fn local_read(path: &str) -> Value {
    match fs::read_to_string(path) {
        Ok(content) => json!({ "status_code": 200, "content": content }),
        Err(e) => io_error(e),
    }
}

pub fn local_write(path: &str, content: &str) -> Value {
    let p = Path::new(path);
    if let Some(parent) = p.parent() {
        if !parent.as_os_str().is_empty() {
            if let Err(e) = fs::create_dir_all(parent) {
                return io_error(e);
            }
        }
    }
    match fs::File::create(path).and_then(|mut f| f.write_all(content.as_bytes())) {
        Ok(()) => json!({ "status_code": 200 }),
        Err(e) => io_error(e),
    }
}

pub fn local_move(src: &str, dest: &str) -> Value {
    match fs::rename(src, dest) {
        Ok(()) => json!({ "status_code": 200 }),
        Err(e) => io_error(e),
    }
}
