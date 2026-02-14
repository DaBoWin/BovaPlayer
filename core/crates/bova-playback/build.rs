fn main() {
    #[cfg(feature = "mpv")]
    {
        // 设置MPV库路径
        println!("cargo:rustc-link-search=native=/opt/homebrew/opt/mpv/lib");
        println!("cargo:rustc-link-lib=mpv");
        
        // 设置包含路径
        println!("cargo:rustc-env=PKG_CONFIG_PATH=/opt/homebrew/opt/mpv/lib/pkgconfig");
    }
}