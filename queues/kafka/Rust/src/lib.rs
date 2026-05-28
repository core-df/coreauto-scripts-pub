// Copyright Core DF — Apache License 2.0
pub mod kafkaclient;
pub mod result;
pub use kafkaclient::{consume, init, produce};
