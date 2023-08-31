// SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
//
// SPDX-License-Identifier: GLWTPL

use std::env;

use a2s::A2SClient;

fn main() {
    let addr = format!(
        "{}:{}",
        env::var("VR_QUERY_HOST").unwrap_or_else(|_| "127.0.0.1".into()),
        env::var("VR_QUERY_PORT").unwrap_or_else(|_| "9877".into())
    );

    let client = A2SClient::new().expect("couldn't create client");
    client.info(addr).expect("couldn't get info");
}
