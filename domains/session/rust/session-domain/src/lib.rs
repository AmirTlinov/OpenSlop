use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use std::fmt::{Display, Formatter};
use std::fs;
use std::path::{Path, PathBuf};

const STORE_RELATIVE_PATH: &str = ".openslop/state/session-store.sqlite3";
const PROJECTION_KIND: &str = "session_list";
const PROOF_SESSION_ID: &str = "s02-persisted-session-store";

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

#[derive(Debug)]
pub enum SessionStoreError {
    Io(std::io::Error),
    Sqlite(rusqlite::Error),
}

impl Display for SessionStoreError {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            SessionStoreError::Io(error) => write!(f, "io error: {error}"),
            SessionStoreError::Sqlite(error) => write!(f, "sqlite error: {error}"),
        }
    }
}

impl std::error::Error for SessionStoreError {}

impl From<std::io::Error> for SessionStoreError {
    fn from(value: std::io::Error) -> Self {
        SessionStoreError::Io(value)
    }
}

impl From<rusqlite::Error> for SessionStoreError {
    fn from(value: rusqlite::Error) -> Self {
        SessionStoreError::Sqlite(value)
    }
}

pub fn session_store_path(repo_root: &Path) -> PathBuf {
    repo_root.join(STORE_RELATIVE_PATH)
}

pub fn bootstrap_session_projection() -> SessionListProjection {
    SessionListProjection {
        kind: PROJECTION_KIND.to_string(),
        sessions: bootstrap_sessions(),
    }
}

pub fn load_persisted_session_projection(repo_root: &Path) -> Result<SessionListProjection, SessionStoreError> {
    let mut connection = open_store(repo_root)?;
    seed_bootstrap_if_empty(&mut connection)?;

    let mut statement = connection.prepare(
        r#"
        SELECT id, title, workspace, branch, provider, status
        FROM sessions
        ORDER BY sort_order ASC, id ASC
        "#,
    )?;

    let sessions = statement
        .query_map([], |row| {
            Ok(SessionSummary {
                id: row.get(0)?,
                title: row.get(1)?,
                workspace: row.get(2)?,
                branch: row.get(3)?,
                provider: row.get(4)?,
                status: row.get(5)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

    Ok(SessionListProjection {
        kind: PROJECTION_KIND.to_string(),
        sessions,
    })
}

pub fn upsert_proof_session(repo_root: &Path) -> Result<(), SessionStoreError> {
    let mut connection = open_store(repo_root)?;
    seed_bootstrap_if_empty(&mut connection)?;

    let proof = SessionSummary {
        id: PROOF_SESSION_ID.to_string(),
        title: "S02 persisted session store".to_string(),
        workspace: "OpenSlop".to_string(),
        branch: "main".to_string(),
        provider: "Codex".to_string(),
        status: "persisted".to_string(),
    };

    upsert_session(&connection, &proof, 90)?;
    Ok(())
}

pub fn reset_session_store(repo_root: &Path) -> Result<(), SessionStoreError> {
    let store_path = session_store_path(repo_root);
    remove_if_exists(&store_path)?;
    remove_if_exists(&store_path.with_extension("sqlite3-shm"))?;
    remove_if_exists(&store_path.with_extension("sqlite3-wal"))?;
    Ok(())
}

pub fn proof_session_id() -> &'static str {
    PROOF_SESSION_ID
}

fn remove_if_exists(path: &Path) -> Result<(), SessionStoreError> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(SessionStoreError::Io(error)),
    }
}

fn open_store(repo_root: &Path) -> Result<Connection, SessionStoreError> {
    let store_path = session_store_path(repo_root);
    if let Some(parent) = store_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let connection = Connection::open(store_path)?;
    connection.execute_batch(
        r#"
        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            sort_order INTEGER NOT NULL,
            title TEXT NOT NULL,
            workspace TEXT NOT NULL,
            branch TEXT NOT NULL,
            provider TEXT NOT NULL,
            status TEXT NOT NULL
        );
        "#,
    )?;
    Ok(connection)
}

fn seed_bootstrap_if_empty(connection: &mut Connection) -> Result<(), SessionStoreError> {
    let count: i64 = connection.query_row("SELECT COUNT(*) FROM sessions", [], |row| row.get(0))?;
    if count > 0 {
        return Ok(());
    }

    let transaction = connection.transaction()?;
    for (index, session) in bootstrap_sessions().iter().enumerate() {
        upsert_session(&transaction, session, ((index + 1) as i64) * 10)?;
    }
    transaction.commit()?;
    Ok(())
}

fn upsert_session(connection: &Connection, session: &SessionSummary, sort_order: i64) -> Result<(), SessionStoreError> {
    connection.execute(
        r#"
        INSERT INTO sessions (id, sort_order, title, workspace, branch, provider, status)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
        ON CONFLICT(id) DO UPDATE SET
            sort_order = excluded.sort_order,
            title = excluded.title,
            workspace = excluded.workspace,
            branch = excluded.branch,
            provider = excluded.provider,
            status = excluded.status
        "#,
        params![
            session.id,
            sort_order,
            session.title,
            session.workspace,
            session.branch,
            session.provider,
            session.status,
        ],
    )?;
    Ok(())
}

fn bootstrap_sessions() -> Vec<SessionSummary> {
    vec![
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
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn bootstrap_projection_has_expected_shape() {
        let projection = bootstrap_session_projection();

        assert_eq!(projection.kind, PROJECTION_KIND);
        assert!(projection.sessions.len() >= 3);
        assert!(projection.sessions.iter().any(|session| session.id == "s02-event-spine"));
    }

    #[test]
    fn bootstrap_projection_serializes_to_json() {
        let projection = bootstrap_session_projection();
        let json = serde_json::to_string(&projection).expect("projection should serialize");

        assert!(json.contains(PROJECTION_KIND));
        assert!(json.contains("s00-repo-constitution"));
    }

    #[test]
    fn persisted_projection_seeds_and_rehydrates() {
        let temp = tempdir().expect("temp dir should exist");

        let seeded = load_persisted_session_projection(temp.path()).expect("projection should load");
        assert_eq!(seeded.kind, PROJECTION_KIND);
        assert_eq!(seeded.sessions.len(), 3);
        assert!(session_store_path(temp.path()).exists());

        upsert_proof_session(temp.path()).expect("proof session should persist");
        let rehydrated = load_persisted_session_projection(temp.path()).expect("projection should rehydrate");

        assert!(rehydrated.sessions.iter().any(|session| session.id == proof_session_id()));
        assert_eq!(rehydrated.sessions.len(), 4);
    }

    #[test]
    fn reset_clears_store() {
        let temp = tempdir().expect("temp dir should exist");
        upsert_proof_session(temp.path()).expect("proof session should persist");
        reset_session_store(temp.path()).expect("store should reset");

        let projection = load_persisted_session_projection(temp.path()).expect("projection should reseed");
        assert_eq!(projection.sessions.len(), 3);
        assert!(!projection.sessions.iter().any(|session| session.id == proof_session_id()));
    }
}
