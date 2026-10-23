#[cfg(target_os = "macos")]
fn main() -> anyhow::Result<()> {
    claurst_tools::desktop_table::parser::main()
}
#[cfg(not(target_os = "macos"))]
fn main() {
    eprintln!("The desktop table parser requires macOS.");
    std::process::exit(1);
}
