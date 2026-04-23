use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;

const MAX_CHANGED_FILES: usize = 120;
const MAX_DIFF_LINES: usize = 240;
const MAX_DIFF_STAT_LINES: usize = 80;
const MAX_FILE_PREVIEW_LINES: usize = 160;
const MAX_FILE_PREVIEW_BYTES: usize = 64 * 1024;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitReviewSnapshot {
    pub kind: String,
    pub repo_root: String,
    pub branch: String,
    pub head: String,
    pub is_git_repository: bool,
    pub has_changes: bool,
    pub status_state: String,
    pub selected_path: Option<String>,
    pub changed_files: Vec<GitChangedFile>,
    pub diff_stat: GitBoundedText,
    pub diff: GitBoundedText,
    pub file_preview: Option<GitFilePreview>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitChangedFile {
    pub path: String,
    pub status: String,
    pub staged: bool,
    pub unstaged: bool,
    pub untracked: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitBoundedText {
    pub text: String,
    pub line_count: usize,
    pub truncated: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GitFilePreview {
    pub path: String,
    pub text: String,
    pub line_count: usize,
    pub truncated: bool,
    pub binary: bool,
}

pub fn load_git_review_snapshot(repo_root: &Path, focused_path: Option<&str>) -> GitReviewSnapshot {
    let mut warnings = Vec::new();
    let display_root = repo_root.display().to_string();

    let worktree_root = match git_text(repo_root, &["rev-parse", "--show-toplevel"]) {
        Ok(root) => PathBuf::from(root.trim()),
        Err(error) => {
            return GitReviewSnapshot {
                kind: "git_review_snapshot".to_string(),
                repo_root: display_root,
                branch: "unknown".to_string(),
                head: "unknown".to_string(),
                is_git_repository: false,
                has_changes: false,
                status_state: "unavailable".to_string(),
                selected_path: None,
                changed_files: Vec::new(),
                diff_stat: GitBoundedText::empty(),
                diff: GitBoundedText::empty(),
                file_preview: None,
                warnings: vec![format!("not a git worktree: {error}")],
            };
        }
    };

    let branch = git_text(&worktree_root, &["branch", "--show-current"])
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "detached".to_string());

    let head = git_text(&worktree_root, &["rev-parse", "--short", "HEAD"])
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "unknown".to_string());

    let (mut changed_files, status_state) = match git_status(&worktree_root) {
        Ok(files) => {
            let state = if files.is_empty() { "clean" } else { "dirty" };
            (files, state.to_string())
        }
        Err(error) => {
            warnings.push(format!("git status failed: {error}"));
            (Vec::new(), "unknown".to_string())
        }
    };

    if changed_files.len() > MAX_CHANGED_FILES {
        warnings.push(format!(
            "changed file list truncated from {} to {} entries",
            changed_files.len(),
            MAX_CHANGED_FILES
        ));
        changed_files.truncate(MAX_CHANGED_FILES);
    }

    let selected_path = select_path(focused_path, &changed_files, &mut warnings);
    let diff_stat = tracked_diff_stat(&worktree_root, selected_path.as_deref(), &mut warnings);
    let diff = tracked_diff(&worktree_root, selected_path.as_deref(), &mut warnings);
    let file_preview = selected_path
        .as_deref()
        .and_then(|path| file_preview(&worktree_root, path, &mut warnings));

    if diff.truncated {
        warnings.push(format!("diff truncated to {MAX_DIFF_LINES} lines"));
    }

    if diff_stat.truncated {
        warnings.push(format!(
            "diff stat truncated to {MAX_DIFF_STAT_LINES} lines"
        ));
    }

    if let Some(preview) = &file_preview {
        if preview.truncated {
            warnings.push(format!(
                "file preview for {} truncated to {} lines / {} bytes",
                preview.path, MAX_FILE_PREVIEW_LINES, MAX_FILE_PREVIEW_BYTES
            ));
        }
    }

    GitReviewSnapshot {
        kind: "git_review_snapshot".to_string(),
        repo_root: worktree_root.display().to_string(),
        branch,
        head,
        is_git_repository: true,
        has_changes: status_state == "dirty",
        status_state,
        selected_path,
        changed_files,
        diff_stat,
        diff,
        file_preview,
        warnings,
    }
}

impl GitBoundedText {
    fn empty() -> Self {
        Self {
            text: String::new(),
            line_count: 0,
            truncated: false,
        }
    }
}

fn select_path(
    focused_path: Option<&str>,
    changed_files: &[GitChangedFile],
    warnings: &mut Vec<String>,
) -> Option<String> {
    if let Some(path) = focused_path.and_then(normalize_requested_path) {
        if changed_files.iter().any(|file| file.path == path) {
            return Some(path);
        }
        warnings.push(format!("requested gitPath is not in changed files: {path}"));
    }

    None
}

fn normalize_requested_path(path: &str) -> Option<String> {
    let trimmed = path.trim();
    if trimmed.is_empty() || trimmed.contains('\0') || trimmed.starts_with('/') {
        return None;
    }
    Some(trimmed.to_string())
}

fn git_status(repo_root: &Path) -> Result<Vec<GitChangedFile>, String> {
    let raw = git_bytes(repo_root, &["status", "--porcelain=v1", "-z"])?;
    let chunks: Vec<&[u8]> = raw
        .split(|byte| *byte == 0)
        .filter(|chunk| !chunk.is_empty())
        .collect();

    let mut files = Vec::new();
    let mut index = 0;
    while index < chunks.len() {
        let record = chunks[index];
        if record.len() < 4 {
            index += 1;
            continue;
        }

        let x = record[0] as char;
        let y = record[1] as char;
        let status = format!("{x}{y}");
        let path = String::from_utf8_lossy(&record[3..]).to_string();
        let staged = x != ' ' && x != '?';
        let unstaged = y != ' ' && y != '?';
        let untracked = x == '?' && y == '?';

        files.push(GitChangedFile {
            path,
            status,
            staged,
            unstaged,
            untracked,
        });

        index += 1;
        if matches!(x, 'R' | 'C') && index < chunks.len() {
            index += 1;
        }
    }

    Ok(files)
}

fn tracked_diff_stat(
    repo_root: &Path,
    selected_path: Option<&str>,
    warnings: &mut Vec<String>,
) -> GitBoundedText {
    let mut parts = Vec::new();

    match git_for_optional_path(repo_root, &["diff", "--stat", "--"], selected_path) {
        Ok(output) if !output.trim().is_empty() => parts.push(output),
        Ok(_) => {}
        Err(error) => warnings.push(format!("git diff --stat failed: {error}")),
    }

    match git_for_optional_path(
        repo_root,
        &["diff", "--cached", "--stat", "--"],
        selected_path,
    ) {
        Ok(output) if !output.trim().is_empty() => parts.push(output),
        Ok(_) => {}
        Err(error) => warnings.push(format!("git diff --cached --stat failed: {error}")),
    }

    bound_text(&parts.join("\n"), MAX_DIFF_STAT_LINES)
}

fn tracked_diff(
    repo_root: &Path,
    selected_path: Option<&str>,
    warnings: &mut Vec<String>,
) -> GitBoundedText {
    let mut parts = Vec::new();

    match git_for_optional_path(repo_root, &["diff", "--no-ext-diff", "--"], selected_path) {
        Ok(output) if !output.trim().is_empty() => parts.push(output),
        Ok(_) => {}
        Err(error) => warnings.push(format!("git diff failed: {error}")),
    }

    match git_for_optional_path(
        repo_root,
        &["diff", "--cached", "--no-ext-diff", "--"],
        selected_path,
    ) {
        Ok(output) if !output.trim().is_empty() => {
            if parts.is_empty() {
                parts.push(output);
            } else {
                parts.push(format!("\n# staged diff\n{output}"));
            }
        }
        Ok(_) => {}
        Err(error) => warnings.push(format!("git diff --cached failed: {error}")),
    }

    bound_text(&parts.join("\n"), MAX_DIFF_LINES)
}

fn file_preview(
    worktree_root: &Path,
    git_path: &str,
    warnings: &mut Vec<String>,
) -> Option<GitFilePreview> {
    let root = match fs::canonicalize(worktree_root) {
        Ok(root) => root,
        Err(error) => {
            warnings.push(format!("cannot canonicalize worktree root: {error}"));
            return None;
        }
    };

    let candidate = worktree_root.join(git_path);
    let metadata = match fs::symlink_metadata(&candidate) {
        Ok(metadata) => metadata,
        Err(_) => return None,
    };

    if metadata.file_type().is_symlink() {
        warnings.push(format!("file preview skipped symlink: {git_path}"));
        return None;
    }

    if !metadata.is_file() {
        return None;
    }

    let canonical = match fs::canonicalize(&candidate) {
        Ok(path) => path,
        Err(error) => {
            warnings.push(format!(
                "cannot canonicalize preview path {git_path}: {error}"
            ));
            return None;
        }
    };

    if !canonical.starts_with(&root) {
        warnings.push(format!(
            "file preview rejected path outside worktree: {git_path}"
        ));
        return None;
    }

    let mut file = match File::open(&canonical) {
        Ok(file) => file,
        Err(error) => {
            warnings.push(format!("cannot open preview path {git_path}: {error}"));
            return None;
        }
    };

    let mut bytes = Vec::with_capacity(MAX_FILE_PREVIEW_BYTES + 1);
    let mut limited = file.by_ref().take((MAX_FILE_PREVIEW_BYTES + 1) as u64);
    if let Err(error) = limited.read_to_end(&mut bytes) {
        warnings.push(format!("cannot read preview path {git_path}: {error}"));
        return None;
    }

    let bytes_truncated = bytes.len() > MAX_FILE_PREVIEW_BYTES;
    if bytes_truncated {
        bytes.truncate(MAX_FILE_PREVIEW_BYTES);
    }

    if bytes.contains(&0) {
        return Some(GitFilePreview {
            path: git_path.to_string(),
            text: String::new(),
            line_count: 0,
            truncated: bytes_truncated,
            binary: true,
        });
    }

    let text = match std::str::from_utf8(&bytes) {
        Ok(text) => text,
        Err(_) => {
            return Some(GitFilePreview {
                path: git_path.to_string(),
                text: String::new(),
                line_count: 0,
                truncated: bytes_truncated,
                binary: true,
            });
        }
    };

    let bounded = bound_text(text, MAX_FILE_PREVIEW_LINES);
    Some(GitFilePreview {
        path: git_path.to_string(),
        text: bounded.text,
        line_count: bounded.line_count,
        truncated: bounded.truncated || bytes_truncated,
        binary: false,
    })
}

fn bound_text(text: &str, max_lines: usize) -> GitBoundedText {
    if text.is_empty() {
        return GitBoundedText::empty();
    }

    let lines: Vec<&str> = text.lines().collect();
    let line_count = lines.len();
    let truncated = line_count > max_lines;
    let visible = if truncated {
        lines[..max_lines].join("\n")
    } else {
        text.to_string()
    };

    GitBoundedText {
        text: visible,
        line_count,
        truncated,
    }
}

fn git_for_optional_path(
    repo_root: &Path,
    prefix_args: &[&str],
    selected_path: Option<&str>,
) -> Result<String, String> {
    let mut args = prefix_args
        .iter()
        .map(|arg| (*arg).to_string())
        .collect::<Vec<_>>();
    if let Some(path) = selected_path {
        args.push(path.to_string());
    }
    git_text_owned(repo_root, &args)
}

fn git_text(repo_root: &Path, args: &[&str]) -> Result<String, String> {
    git_text_owned(
        repo_root,
        &args
            .iter()
            .map(|arg| (*arg).to_string())
            .collect::<Vec<_>>(),
    )
}

fn git_text_owned(repo_root: &Path, args: &[String]) -> Result<String, String> {
    let output = run_git(repo_root, args)?;
    Ok(String::from_utf8_lossy(&output).to_string())
}

fn git_bytes(repo_root: &Path, args: &[&str]) -> Result<Vec<u8>, String> {
    let args = args
        .iter()
        .map(|arg| (*arg).to_string())
        .collect::<Vec<_>>();
    run_git(repo_root, &args)
}

fn run_git(repo_root: &Path, args: &[String]) -> Result<Vec<u8>, String> {
    let output = Command::new("git")
        .env("GIT_OPTIONAL_LOCKS", "0")
        .arg("-C")
        .arg(repo_root)
        .args(args)
        .output()
        .map_err(|error| error.to_string())?;

    if output.status.success() {
        Ok(output.stdout)
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        let message = if stderr.is_empty() {
            format!("git exited with status {}", output.status)
        } else {
            stderr
        };
        Err(message)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn snapshot_reports_dirty_fixture_without_mutating_git() {
        let temp = tempdir().expect("tempdir");
        init_repo(temp.path());
        fs::create_dir_all(temp.path().join("src")).expect("src dir");
        fs::write(temp.path().join("src/app.txt"), "before\n").expect("write app");
        run(temp.path(), &["add", "."]);
        run(temp.path(), &["commit", "-m", "initial"]);

        fs::write(temp.path().join("src/app.txt"), "before\nchanged\n").expect("modify app");
        fs::write(temp.path().join("notes.md"), "scratch\n").expect("write notes");

        let before =
            git_bytes(temp.path(), &["status", "--porcelain=v1", "-z"]).expect("status before");
        let snapshot = load_git_review_snapshot(temp.path(), Some("src/app.txt"));
        let after =
            git_bytes(temp.path(), &["status", "--porcelain=v1", "-z"]).expect("status after");

        assert_eq!(before, after, "snapshot must not mutate git state");
        assert_eq!(snapshot.kind, "git_review_snapshot");
        assert!(snapshot.is_git_repository);
        assert!(snapshot.has_changes);
        assert_eq!(snapshot.status_state, "dirty");
        assert!(!snapshot.branch.is_empty());
        assert_ne!(snapshot.head, "unknown");
        assert_eq!(snapshot.selected_path.as_deref(), Some("src/app.txt"));
        assert!(
            snapshot
                .changed_files
                .iter()
                .any(|file| file.path == "src/app.txt")
        );
        assert!(
            snapshot
                .changed_files
                .iter()
                .any(|file| file.path == "notes.md" && file.untracked)
        );
        assert!(snapshot.diff.text.contains("+changed"));
        assert!(
            snapshot
                .file_preview
                .as_ref()
                .is_some_and(|preview| preview.text.contains("changed"))
        );
        assert!(!snapshot.diff.truncated);
    }

    #[test]
    fn snapshot_fails_closed_outside_git() {
        let temp = tempdir().expect("tempdir");
        let snapshot = load_git_review_snapshot(temp.path(), None);

        assert_eq!(snapshot.kind, "git_review_snapshot");
        assert!(!snapshot.is_git_repository);
        assert!(!snapshot.has_changes);
        assert_eq!(snapshot.status_state, "unavailable");
        assert!(snapshot.changed_files.is_empty());
        assert!(
            snapshot
                .warnings
                .iter()
                .any(|warning| warning.contains("not a git worktree"))
        );
    }

    fn init_repo(path: &Path) {
        run(path, &["init"]);
        run(path, &["config", "user.email", "openslop@example.invalid"]);
        run(path, &["config", "user.name", "OpenSlop Probe"]);
    }

    fn run(path: &Path, args: &[&str]) {
        let output = Command::new("git")
            .arg("-C")
            .arg(path)
            .args(args)
            .output()
            .expect("git command");
        assert!(
            output.status.success(),
            "git {:?} failed: {}",
            args,
            String::from_utf8_lossy(&output.stderr)
        );
    }
}
