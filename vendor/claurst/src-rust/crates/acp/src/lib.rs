//! Agent Client Protocol (ACP) server for Claurst.
//!
//! ACP is the open protocol pioneered by Zed for standardizing communication
//! between AI coding agents and editors (Zed, Neovim, JetBrains, VS Code, …).
//! Spec: <https://agentclientprotocol.com>
//!
//! This crate turns the local `claurst` binary into a compliant ACP agent
//! over newline-delimited JSON-RPC 2.0 on stdio. Editors launch `claurst acp`
//! as a subprocess and drive it through the protocol's standard methods:
//!
//! | Method                       | Direction  | Notes                                       |
//! |------------------------------|------------|---------------------------------------------|
//! | `initialize`                 | C → A      | Capability negotiation                      |
//! | `authenticate`               | C → A      | No-op (Claurst uses local credentials)      |
//! | `session/new`                | C → A      | Create a session with cwd + MCP roster      |
//! | `session/prompt`             | C → A      | Run a turn; streams `session/update` events |
//! | `session/cancel`             | C → A (no resp) | Cancel an in-flight prompt             |
//! | `session/update`             | A → C (no resp) | Streamed text/tool deltas              |
//! | `session/request_permission` | A → C      | Tool approval dialog                        |
//!
//! Per-session MCP server configs supplied via `session/new` are accepted
//! but currently ignored in favour of the MCP servers configured in the
//! settings for the session's working directory. This will be resolved as part of the planned unified MCP routing work
//! (see `src-rust/plan/migration-todo.md`).

mod connection;
mod desktop;
#[cfg(target_os = "macos")]
mod desktop_command;
#[cfg(target_os = "macos")]
mod desktop_latex;
mod desktop_question;
mod desktop_read;
#[cfg(unix)]
mod desktop_restore;
mod desktop_search;
mod desktop_web;
mod permission;
mod prompt;
mod runtime;
mod server;
mod sessions;

#[cfg(test)]
mod e2e_tests;

use tokio::sync::mpsc;
use tracing::{error, info};

pub use connection::Connection;
pub use runtime::AgentRuntime;
pub use server::AgentServer;

/// Run the ACP server on the current process' stdin / stdout. Returns when
/// stdin reaches EOF.
pub async fn run_acp_server() -> anyhow::Result<()> {
    run_server(false).await
}

/// Explicitly configured, isolated desktop entry point.
pub async fn run_desktop_server() -> anyhow::Result<()> {
    run_server(true).await
}

async fn run_server(desktop: bool) -> anyhow::Result<()> {
    // We must NEVER write to stdout outside the protocol — every byte on
    // stdout is parsed by the client as JSON-RPC. Force logs to stderr.
    install_stderr_tracing();

    info!(version = env!("CARGO_PKG_VERSION"), "ACP: starting server");

    // Runtimes are built per session working directory on `session/new`.
    let connection = Connection::new(tokio::io::stdout());
    let server = if desktop {
        AgentServer::new_desktop(connection.clone())
    } else {
        AgentServer::new(connection.clone())
    };

    let (tx, mut rx) = mpsc::unbounded_channel();
    let reader_fut = connection::run_reader(connection, tokio::io::stdin(), tx);

    // Track in-flight dispatch tasks so they can finish writing their
    // responses before the runtime shuts down. The dispatch future only
    // returns once the reader has dropped `tx` (closing `rx`) AND every
    // spawned handler has resolved.
    let dispatch_fut = async {
        let mut tasks: Vec<tokio::task::JoinHandle<()>> = Vec::new();
        while let Some(msg) = rx.recv().await {
            tasks.push(server.dispatch(msg));
        }
        // The desktop owns this process. EOF means its window/process has
        // disconnected, so unfinished work must be dropped before we exit.
        // Awaiting aborted handlers runs their child-process and TempDir guards;
        // killing this runtime from the client would skip those destructors.
        if desktop {
            // A tool can synchronously wait for a permission decision. Resolve
            // connection requests first so that blocking wait denies the request
            // and returns; abort alone cannot interrupt block_in_place.
            server.connection.close();
            for handle in &tasks {
                handle.abort();
            }
        }
        for handle in tasks {
            let _ = handle.await;
        }
    };

    let (reader_res, _) = tokio::join!(reader_fut, dispatch_fut);
    if let Err(e) = reader_res {
        error!(?e, "ACP: reader loop failed");
    }

    info!("ACP: server shutdown");
    Ok(())
}

fn install_stderr_tracing() {
    use tracing_subscriber::{fmt, EnvFilter};
    let _ = fmt()
        .with_env_filter(
            EnvFilter::try_from_env("CLAURST_ACP_LOG").unwrap_or_else(|_| EnvFilter::new("warn")),
        )
        .with_writer(std::io::stderr)
        .try_init();
}
