// SPDX-License-Identifier: GPL-3.0-only
//! Application binary: Slint UI on KMS/DRM with libmpv render (OpenGL ES).

const VERSION: &str = env!("CARGO_PKG_VERSION");
const GIT_HASH: &str = env!("EGSOB_GIT_HASH");
const BUILD_TIME: &str = env!("EGSOB_BUILD_TIME");

fn main() {
    println!("egsob {VERSION} ({GIT_HASH}, {BUILD_TIME})");
}
