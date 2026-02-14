fn main() {
    #[cfg(feature = "mpv")]
    {
        // 尝试使用 pkg-config 查找 MPV
        if let Ok(_) = pkg_config::probe_library("mpv") {
            println!("cargo:rustc-link-lib=mpv");
        } else {
            // 回退到手动设置路径（macOS Homebrew）
            if cfg!(target_os = "macos") {
                // 尝试 ARM64 路径
                if std::path::Path::new("/opt/homebrew/opt/mpv/lib").exists() {
                    println!("cargo:rustc-link-search=native=/opt/homebrew/opt/mpv/lib");
                    println!("cargo:rustc-link-lib=mpv");
                } 
                // 尝试 x86_64 路径
                else if std::path::Path::new("/usr/local/opt/mpv/lib").exists() {
                    println!("cargo:rustc-link-search=native=/usr/local/opt/mpv/lib");
                    println!("cargo:rustc-link-lib=mpv");
                }
            } else {
                println!("cargo:rustc-link-lib=mpv");
            }
        }
    }
}
