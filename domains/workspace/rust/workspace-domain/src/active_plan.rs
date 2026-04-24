use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActivePlanProjection {
    pub kind: String,
    pub generated_at_unix_ms: u128,
    pub roadmap_path: String,
    pub active_slice_id: Option<String>,
    pub selection_reason: String,
    pub counts: ActivePlanCounts,
    pub slices: Vec<ActivePlanSlice>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActivePlanCounts {
    pub total: usize,
    pub done: usize,
    pub active: usize,
    pub planned: usize,
    pub blocked: usize,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ActivePlanSlice {
    pub id: String,
    pub outcome: String,
    pub depends_on: String,
    pub status: String,
    pub roadmap_status: String,
    pub slice_path: String,
    pub review_status: String,
    pub proof_status: String,
    pub visual_status: String,
}

#[derive(Debug, Clone)]
struct RoadmapSlice {
    id: String,
    outcome: String,
    depends_on: String,
    status: String,
}

pub fn load_active_plan_projection(repo_root: &Path) -> ActivePlanProjection {
    let roadmap_path = repo_root.join("ROADMAP.md");
    let mut warnings = Vec::new();
    let roadmap_text = match fs::read_to_string(&roadmap_path) {
        Ok(text) => text,
        Err(error) => {
            warnings.push(format!("ROADMAP.md unavailable: {error}"));
            String::new()
        }
    };

    let roadmap_slices = parse_roadmap_slices(&roadmap_text);
    if roadmap_slices.is_empty() {
        warnings.push("ROADMAP.md has no slice rows".to_string());
    }

    let slices: Vec<ActivePlanSlice> = roadmap_slices
        .into_iter()
        .map(|slice| materialize_slice(repo_root, slice))
        .collect();
    let active_slice_id = slices
        .iter()
        .find(|slice| slice.status != "done")
        .map(|slice| slice.id.clone());
    let selection_reason = if slices.is_empty() {
        "roadmap unavailable or has no slice rows".to_string()
    } else if active_slice_id.is_some() {
        "first non-done roadmap slice".to_string()
    } else {
        "all roadmap slices done".to_string()
    };
    let counts = count_slices(&slices);

    ActivePlanProjection {
        kind: "active_plan_projection".to_string(),
        generated_at_unix_ms: unix_ms_now(),
        roadmap_path: display_path(&roadmap_path),
        active_slice_id,
        selection_reason,
        counts,
        slices,
        warnings,
    }
}

impl ActivePlanProjection {
    pub fn is_unavailable(&self) -> bool {
        self.slices.is_empty()
    }
}

fn parse_roadmap_slices(text: &str) -> Vec<RoadmapSlice> {
    text.lines().filter_map(parse_roadmap_slice_line).collect()
}

fn parse_roadmap_slice_line(line: &str) -> Option<RoadmapSlice> {
    let trimmed = line.trim();
    if !trimmed.starts_with('|') || !trimmed.contains('`') {
        return None;
    }

    let cells: Vec<String> = trimmed
        .trim_matches('|')
        .split('|')
        .map(|cell| cell.trim().to_string())
        .collect();
    if cells.len() < 4 {
        return None;
    }

    let id = cells[0].trim_matches('`').to_string();
    if id.is_empty() || id == "Slice" {
        return None;
    }

    Some(RoadmapSlice {
        id,
        outcome: cells[1].to_string(),
        depends_on: cells[2].to_string(),
        status: normalize_status(&cells[3]),
    })
}

fn materialize_slice(repo_root: &Path, roadmap: RoadmapSlice) -> ActivePlanSlice {
    let slice_dir = repo_root.join("plans/slices").join(&roadmap.id);
    let status_path = slice_dir.join("STATUS.md");
    let review_path = slice_dir.join("REVIEW.md");
    let visual_path = slice_dir.join("VISUAL-CHECK.md");

    let status_text = read_optional(&status_path);
    let review_text = read_optional(&review_path);
    let visual_text = read_optional(&visual_path);

    ActivePlanSlice {
        id: roadmap.id,
        outcome: roadmap.outcome,
        depends_on: roadmap.depends_on,
        status: status_text
            .as_deref()
            .and_then(parse_status_file_status)
            .unwrap_or_else(|| roadmap.status.clone()),
        roadmap_status: roadmap.status,
        slice_path: display_path(&slice_dir),
        review_status: review_text
            .as_deref()
            .map(parse_review_status)
            .unwrap_or_else(|| "missing".to_string()),
        proof_status: review_text
            .as_deref()
            .map(parse_proof_status)
            .unwrap_or_else(|| "missing".to_string()),
        visual_status: visual_text
            .as_deref()
            .map(parse_visual_status)
            .unwrap_or_else(|| "missing".to_string()),
    }
}

fn read_optional(path: &Path) -> Option<String> {
    fs::read_to_string(path).ok()
}

fn parse_status_file_status(text: &str) -> Option<String> {
    text.lines().find_map(|line| {
        let trimmed = line.trim().trim_start_matches('-').trim();
        trimmed
            .strip_prefix("status:")
            .map(|value| normalize_status(value.trim()))
    })
}

fn parse_review_status(text: &str) -> String {
    text.lines()
        .find_map(|line| {
            let trimmed = line.trim();
            trimmed
                .strip_prefix("Status:")
                .map(|value| normalize_status(value.trim()))
        })
        .unwrap_or_else(|| "unknown".to_string())
}

fn parse_proof_status(text: &str) -> String {
    let mut saw_pass = false;
    let mut saw_receipt = false;
    let mut in_receipts = false;

    for line in text.lines() {
        let heading = line.trim().to_ascii_lowercase();
        if heading.starts_with("## ") {
            in_receipts =
                heading.contains("local proof receipts") || heading.contains("proof receipts");
            continue;
        }

        if !in_receipts {
            continue;
        }

        let normalized = line.trim().to_ascii_lowercase();
        if !normalized.starts_with('-') {
            continue;
        }
        if normalized.contains("fail") || normalized.contains("block") {
            return "fail".to_string();
        }
        if normalized.contains("pass") {
            saw_pass = true;
        }
        if normalized.contains('`')
            || normalized.contains("make ")
            || normalized.contains("swift ")
            || normalized.contains("cargo ")
        {
            saw_receipt = true;
        }
    }

    if saw_pass {
        "pass".to_string()
    } else if saw_receipt {
        "unknown".to_string()
    } else {
        "missing".to_string()
    }
}

fn parse_visual_status(text: &str) -> String {
    let mut boxes = 0usize;
    let mut checked = 0usize;

    for line in text.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("- [x]") || trimmed.starts_with("- [X]") {
            boxes += 1;
            checked += 1;
        } else if trimmed.starts_with("- [ ]") {
            boxes += 1;
        }
    }

    match (boxes, checked) {
        (0, _) => "missing".to_string(),
        (total, done) if total == done => "pass".to_string(),
        _ => "pending".to_string(),
    }
}

fn count_slices(slices: &[ActivePlanSlice]) -> ActivePlanCounts {
    let mut counts = BTreeMap::<String, usize>::new();
    for slice in slices {
        *counts
            .entry(classify_status(&slice.status).to_string())
            .or_default() += 1;
    }

    ActivePlanCounts {
        total: slices.len(),
        done: *counts.get("done").unwrap_or(&0),
        active: *counts.get("active").unwrap_or(&0),
        planned: *counts.get("planned").unwrap_or(&0),
        blocked: *counts.get("blocked").unwrap_or(&0),
    }
}

fn classify_status(status: &str) -> &str {
    match normalize_status(status).as_str() {
        "done" => "done",
        "blocked" | "block" | "fail" => "blocked",
        "planned" | "pending" => "planned",
        _ => "active",
    }
}

fn normalize_status(value: &str) -> String {
    value
        .trim()
        .trim_matches('`')
        .trim_matches('*')
        .trim()
        .to_ascii_lowercase()
        .replace(' ', "-")
}

fn display_path(path: &PathBuf) -> String {
    path.display().to_string()
}

fn unix_ms_now() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn reads_roadmap_slice_status_and_review_markers() {
        let temp = tempdir().expect("temp dir");
        fs::write(
            temp.path().join("ROADMAP.md"),
            "| Slice | Outcome | Depends on | Status |\n| --- | --- | --- | --- |\n| `S01-demo` | Demo outcome | S00 | in-review |\n| `S02-next` | Next outcome | S01 | planned |\n",
        )
        .expect("roadmap");
        let slice = temp.path().join("plans/slices/S01-demo");
        fs::create_dir_all(&slice).expect("slice dir");
        fs::write(slice.join("STATUS.md"), "status: done\n").expect("status");
        fs::write(
            slice.join("REVIEW.md"),
            "# REVIEW\n\nStatus: PASS\n\n## Local proof receipts\n\n- `make demo` — PASS\n",
        )
        .expect("review");
        fs::write(slice.join("VISUAL-CHECK.md"), "- [x] Visual pass\n").expect("visual");

        let projection = load_active_plan_projection(temp.path());
        assert_eq!(projection.kind, "active_plan_projection");
        assert_eq!(projection.slices.len(), 2);
        assert_eq!(projection.slices[0].status, "done");
        assert_eq!(projection.slices[0].review_status, "pass");
        assert_eq!(projection.slices[0].proof_status, "pass");
        assert_eq!(projection.slices[0].visual_status, "pass");
        assert_eq!(projection.active_slice_id.as_deref(), Some("S02-next"));
    }

    #[test]
    fn missing_roadmap_fails_closed_without_all_done_claim() {
        let temp = tempdir().expect("temp dir");
        let projection = load_active_plan_projection(temp.path());

        assert!(projection.is_unavailable());
        assert_eq!(
            projection.selection_reason,
            "roadmap unavailable or has no slice rows"
        );
        assert!(projection.active_slice_id.is_none());
        assert_eq!(projection.counts.total, 0);
        assert!(
            projection
                .warnings
                .iter()
                .any(|warning| warning.contains("ROADMAP.md unavailable"))
        );
    }

    #[test]
    fn empty_roadmap_fails_closed_without_all_done_claim() {
        let temp = tempdir().expect("temp dir");
        fs::write(temp.path().join("ROADMAP.md"), "# empty\n").expect("roadmap");

        let projection = load_active_plan_projection(temp.path());

        assert!(projection.is_unavailable());
        assert_eq!(
            projection.selection_reason,
            "roadmap unavailable or has no slice rows"
        );
        assert!(projection.active_slice_id.is_none());
        assert_eq!(projection.counts.total, 0);
        assert!(
            projection
                .warnings
                .iter()
                .any(|warning| warning == "ROADMAP.md has no slice rows")
        );
    }
}
