#[tokio::main]
async fn main() -> anyhow::Result<()> {
    claurst_acp::run_desktop_server().await
}
