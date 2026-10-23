//! Route the existing question tool to the desktop while preserving its reply channel.
use crate::connection::Connection;
use agent_client_protocol_schema as acp;
use claurst_tools::UserQuestionEvent;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct QuestionRequest {
    session_id: acp::SessionId,
    question: String,
    options: Option<Vec<String>>,
}

#[derive(Deserialize)]
struct QuestionResponse {
    answer: Option<String>,
}

pub(crate) async fn forward(
    connection: Arc<Connection>,
    session_id: acp::SessionId,
    mut questions: mpsc::UnboundedReceiver<UserQuestionEvent>,
    finished: CancellationToken,
    cancelled: CancellationToken,
) {
    loop {
        let question = tokio::select! {
            biased;
            _ = finished.cancelled() => return,
            _ = cancelled.cancelled() => return,
            question = questions.recv() => match question {
                Some(question) => question,
                None => return,
            },
        };
        let result = tokio::select! {
            biased;
            _ = finished.cancelled() => return,
            _ = cancelled.cancelled() => return,
            response = connection.send_request::<_, QuestionResponse>(
                "desktop/request_question",
                QuestionRequest {
                    session_id: session_id.clone(),
                    question: question.question,
                    options: question.options,
                },
            ) => response,
        };
        if let Ok(Ok(QuestionResponse {
            answer: Some(answer),
        })) = result
        {
            let _ = question.reply_tx.send(answer);
        } else {
            // Responses are resolved by the connection reader, while the
            // cancellation notification is queued for the server. A nil
            // answer may therefore arrive first. Cancel this turn before
            // dropping the reply sender so no later tool can resume it.
            cancelled.cancel();
            return;
        }
    }
}
