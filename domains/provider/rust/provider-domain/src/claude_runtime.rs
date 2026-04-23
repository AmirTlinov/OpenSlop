use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeRuntimeStatus {
    pub kind: String,
    pub runtime: String,
    pub available: bool,
    pub bridge: ClaudeBridgeSummary,
    pub binary_path: Option<String>,
    pub cli_version: Option<String>,
    pub node_version: Option<String>,
    pub checked_at: String,
    pub capabilities: ClaudeCapabilitySnapshot,
    pub help_signals: Vec<String>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeBridgeSummary {
    pub name: String,
    pub version: String,
    pub transport: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeCapabilitySnapshot {
    pub runtime_discovery: bool,
    pub cli_print_json: bool,
    pub cli_stream_json_output: bool,
    pub cli_stream_json_input: bool,
    pub cli_session_resume: bool,
    pub cli_explicit_session_id: bool,
    pub cli_permission_mode: bool,
    pub cli_mcp_config: bool,
    pub bridge_turn_streaming: bool,
    pub bridge_session_mirror: bool,
    pub bridge_native_approvals: bool,
    pub bridge_tracing_handoff: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ClaudeTurnProofResult {
    pub kind: String,
    pub runtime: String,
    pub success: bool,
    pub runtime_available: bool,
    pub bridge: ClaudeBridgeSummary,
    pub model: Option<String>,
    pub session_id: Option<String>,
    pub result_text: String,
    pub assistant_text: String,
    pub event_count: usize,
    pub event_types: Vec<String>,
    pub tool_use_count: usize,
    pub malformed_event_count: usize,
    pub session_persistence: String,
    pub total_cost_usd: Option<f64>,
    pub duration_ms: Option<u64>,
    pub exit_code: Option<i32>,
    pub signal: Option<String>,
    pub timed_out: bool,
    pub prompt_bytes: usize,
    pub warnings: Vec<String>,
}

impl ClaudeTurnProofResult {
    pub fn unavailable(reason: impl Into<String>) -> Self {
        Self {
            kind: "claude_turn_proof_result".to_string(),
            runtime: "claude-code-cli".to_string(),
            success: false,
            runtime_available: false,
            bridge: ClaudeBridgeSummary {
                name: "claude-bridge".to_string(),
                version: "0.2.0".to_string(),
                transport: "stdio-json".to_string(),
            },
            model: None,
            session_id: None,
            result_text: String::new(),
            assistant_text: String::new(),
            event_count: 0,
            event_types: Vec::new(),
            tool_use_count: 0,
            malformed_event_count: 0,
            session_persistence: "disabled".to_string(),
            total_cost_usd: None,
            duration_ms: None,
            exit_code: None,
            signal: None,
            timed_out: false,
            prompt_bytes: 0,
            warnings: vec![reason.into()],
        }
    }

    pub fn from_bridge_json(raw: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(raw)
    }

    pub fn with_warning(mut self, warning: impl Into<String>) -> Self {
        self.warnings.push(warning.into());
        self
    }
}

impl ClaudeRuntimeStatus {
    pub fn unavailable(reason: impl Into<String>) -> Self {
        Self {
            kind: "claude_runtime_status".to_string(),
            runtime: "claude-code-cli".to_string(),
            available: false,
            bridge: ClaudeBridgeSummary {
                name: "claude-bridge".to_string(),
                version: "0.2.0".to_string(),
                transport: "stdio-json".to_string(),
            },
            binary_path: None,
            cli_version: None,
            node_version: None,
            checked_at: "unknown".to_string(),
            capabilities: ClaudeCapabilitySnapshot::unavailable(),
            help_signals: Vec::new(),
            warnings: vec![reason.into()],
        }
    }

    pub fn from_bridge_json(raw: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(raw)
    }

    pub fn with_warning(mut self, warning: impl Into<String>) -> Self {
        self.warnings.push(warning.into());
        self
    }
}

impl ClaudeCapabilitySnapshot {
    pub fn unavailable() -> Self {
        Self {
            runtime_discovery: false,
            cli_print_json: false,
            cli_stream_json_output: false,
            cli_stream_json_input: false,
            cli_session_resume: false,
            cli_explicit_session_id: false,
            cli_permission_mode: false,
            cli_mcp_config: false,
            bridge_turn_streaming: false,
            bridge_session_mirror: false,
            bridge_native_approvals: false,
            bridge_tracing_handoff: false,
        }
    }

    pub fn from_help_signals(signals: &[String]) -> Self {
        let by_signal: BTreeMap<&str, bool> = signals
            .iter()
            .map(|signal| (signal.as_str(), true))
            .collect();
        Self {
            runtime_discovery: true,
            cli_print_json: by_signal.contains_key("--print")
                && by_signal.contains_key("--output-format"),
            cli_stream_json_output: by_signal.contains_key("--output-format=stream-json"),
            cli_stream_json_input: by_signal.contains_key("--input-format=stream-json"),
            cli_session_resume: by_signal.contains_key("--resume")
                || by_signal.contains_key("--continue"),
            cli_explicit_session_id: by_signal.contains_key("--session-id"),
            cli_permission_mode: by_signal.contains_key("--permission-mode"),
            cli_mcp_config: by_signal.contains_key("--mcp-config"),
            bridge_turn_streaming: false,
            bridge_session_mirror: false,
            bridge_native_approvals: false,
            bridge_tracing_handoff: false,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unavailable_status_is_fail_closed() {
        let status = ClaudeRuntimeStatus::unavailable("missing claude");
        assert_eq!(status.kind, "claude_runtime_status");
        assert!(!status.available);
        assert!(!status.capabilities.runtime_discovery);
        assert_eq!(status.warnings, vec!["missing claude"]);
    }

    #[test]
    fn parses_bridge_turn_proof_result() {
        let raw = r#"{
            "kind":"claude_turn_proof_result",
            "runtime":"claude-code-cli",
            "success":true,
            "runtimeAvailable":true,
            "bridge":{"name":"claude-bridge","version":"0.2.0","transport":"stdio-json"},
            "model":"claude-haiku-4-5-20251001",
            "sessionId":"session-1",
            "resultText":"OPENSLOP_CLAUDE_OK",
            "assistantText":"OPENSLOP_CLAUDE_OK",
            "eventCount":4,
            "eventTypes":["assistant","result:success","system:init"],
            "toolUseCount":0,
            "malformedEventCount":0,
            "sessionPersistence":"disabled",
            "totalCostUsd":0.012,
            "durationMs":1000,
            "exitCode":0,
            "signal":null,
            "timedOut":false,
            "promptBytes":55,
            "warnings":[]
        }"#;
        let proof = ClaudeTurnProofResult::from_bridge_json(raw).expect("valid turn proof json");
        assert!(proof.success);
        assert!(proof.runtime_available);
        assert_eq!(proof.result_text, "OPENSLOP_CLAUDE_OK");
        assert!(proof.event_types.contains(&"result:success".to_string()));
        assert_eq!(proof.tool_use_count, 0);
        assert_eq!(proof.session_persistence, "disabled");
        assert!(!proof.timed_out);
    }

    #[test]
    fn parses_bridge_runtime_status() {
        let raw = r#"{
            "kind":"claude_runtime_status",
            "runtime":"claude-code-cli",
            "available":true,
            "bridge":{"name":"claude-bridge","version":"0.1.0","transport":"stdio-json"},
            "binaryPath":"/bin/claude",
            "cliVersion":"2.1.118 (Claude Code)",
            "nodeVersion":"v22.22.2",
            "checkedAt":"2026-04-24T00:00:00.000Z",
            "capabilities":{
                "runtimeDiscovery":true,
                "cliPrintJson":true,
                "cliStreamJsonOutput":true,
                "cliStreamJsonInput":true,
                "cliSessionResume":true,
                "cliExplicitSessionId":true,
                "cliPermissionMode":true,
                "cliMcpConfig":true,
                "bridgeTurnStreaming":false,
                "bridgeSessionMirror":false,
                "bridgeNativeApprovals":false,
                "bridgeTracingHandoff":false
            },
            "helpSignals":["--print","--output-format"],
            "warnings":[]
        }"#;
        let status = ClaudeRuntimeStatus::from_bridge_json(raw).expect("valid bridge json");
        assert!(status.available);
        assert_eq!(status.bridge.transport, "stdio-json");
        assert_eq!(status.cli_version.as_deref(), Some("2.1.118 (Claude Code)"));
    }
}
