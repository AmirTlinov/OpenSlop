use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SessionSummary {
    pub id: String,
    pub title: String,
    pub workspace: String,
    pub branch: String,
    pub provider: String,
    pub status: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SessionListProjection {
    pub kind: String,
    pub sessions: Vec<SessionSummary>,
}

pub fn bootstrap_session_projection() -> SessionListProjection {
    SessionListProjection {
        kind: "session_list".to_string(),
        sessions: vec![
            SessionSummary {
                id: "s00-repo-constitution".to_string(),
                title: "S00 repo constitution".to_string(),
                workspace: "OpenSlop".to_string(),
                branch: "main".to_string(),
                provider: "Codex".to_string(),
                status: "done".to_string(),
            },
            SessionSummary {
                id: "s02-event-spine".to_string(),
                title: "S02 event spine".to_string(),
                workspace: "OpenSlop".to_string(),
                branch: "main".to_string(),
                provider: "Codex".to_string(),
                status: "in_progress".to_string(),
            },
            SessionSummary {
                id: "claude-runtime-discovery".to_string(),
                title: "Claude runtime discovery".to_string(),
                workspace: "OpenSlop".to_string(),
                branch: "main".to_string(),
                provider: "Claude".to_string(),
                status: "planned".to_string(),
            },
        ],
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bootstrap_projection_has_expected_shape() {
        let projection = bootstrap_session_projection();

        assert_eq!(projection.kind, "session_list");
        assert!(projection.sessions.len() >= 3);
        assert!(projection.sessions.iter().any(|session| session.id == "s02-event-spine"));
    }

    #[test]
    fn bootstrap_projection_serializes_to_json() {
        let projection = bootstrap_session_projection();
        let json = serde_json::to_string(&projection).expect("projection should serialize");

        assert!(json.contains("session_list"));
        assert!(json.contains("s00-repo-constitution"));
    }
}
