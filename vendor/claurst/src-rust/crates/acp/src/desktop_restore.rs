//! Local recovery is independent of provider configuration and credentials.
use crate::connection::Connection;
use agent_client_protocol_schema as acp;
use claurst_core::{
    config::{Config, PermissionMode, Settings},
    permissions::{ManagedInteractivePermissionHandler, PermissionManager},
};
use claurst_tools::ToolContext;
use std::{path::PathBuf, sync::Arc};

#[derive(serde::Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct RestoreFile {
    cwd: PathBuf,
    change_id: String,
}

pub(crate) async fn handle(
    connection: Arc<Connection>,
    request: RestoreFile,
) -> Result<(), acp::Error> {
    if !request.cwd.is_absolute() || !request.cwd.is_dir() {
        return Err(acp::Error::invalid_params());
    }
    let working_dir = request
        .cwd
        .canonicalize()
        .map_err(|_| acp::Error::invalid_params())?;
    let mode = PermissionMode::AcceptEdits;
    let manager = Arc::new(std::sync::Mutex::new(PermissionManager::new(
        mode.clone(),
        &Settings::default(),
    )));
    let pending = Arc::new(parking_lot::Mutex::new(
        claurst_tools::PendingPermissionStore::default(),
    ));
    let cancel = tokio_util::sync::CancellationToken::new();
    let ctx = ToolContext {
        working_dir,
        permission_mode: mode.clone(),
        permission_handler: Arc::new(ManagedInteractivePermissionHandler::new(manager.clone())),
        cost_tracker: claurst_core::CostTracker::new(),
        session_id: format!("recovery-{}", uuid::Uuid::new_v4()),
        file_history: Default::default(),
        current_turn: Default::default(),
        non_interactive: false,
        mcp_manager: None,
        config: Config {
            permission_mode: mode,
            disable_claude_mds: true,
            ..Default::default()
        },
        managed_agent_config: None,
        completion_notifier: None,
        pending_permissions: Some(pending.clone()),
        permission_manager: Some(manager.clone()),
        user_question_tx: None,
        cancel_token: cancel.clone(),
        batch_rejection: Default::default(),
    };
    let drainer = crate::permission::spawn_drainer(
        connection,
        acp::SessionId::new(ctx.session_id.clone()),
        manager,
        pending,
        cancel.clone(),
        cancel.clone(),
    );
    let result = claurst_tools::desktop_write::files::restore(&request.change_id, &ctx).await;
    cancel.cancel();
    let _ = drainer.await;
    result.map_err(|error| {
        acp::Error::new(i32::from(acp::ErrorCode::InternalError), error.to_string())
    })
}
