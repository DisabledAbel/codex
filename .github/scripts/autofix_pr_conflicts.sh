#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  .github/scripts/autofix_pr_conflicts.sh prepare <base_remote> <base_ref>
  .github/scripts/autofix_pr_conflicts.sh finalize <head_ref>
USAGE
}

prepare_merge() {
  local base_remote="$1"
  local base_ref="$2"

  git fetch --no-tags "$base_remote" "$base_ref"

  if git merge --no-commit --no-ff "${base_remote}/${base_ref}"; then
    echo "No merge conflicts were detected."
    git merge --abort >/dev/null 2>&1 || true
    echo "needs_codex=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  if ! git diff --name-only --diff-filter=U > .codex-conflicted-files.txt; then
    echo "Unable to gather conflicted files."
    exit 1
  fi

  if [[ ! -s .codex-conflicted-files.txt ]]; then
    echo "Merge failed but no conflicted files were reported."
    exit 1
  fi

  echo "needs_codex=true" >> "$GITHUB_OUTPUT"
  {
    echo "conflicted_files<<EOF"
    cat .codex-conflicted-files.txt
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  echo "Conflicts detected in:"
  cat .codex-conflicted-files.txt
}

finalize_merge() {
  local head_ref="$1"

  if git diff --name-only --diff-filter=U | grep -q .; then
    echo "Conflicts are still present after Codex changes."
    git status --short
    exit 1
  fi

  if git diff --cached --quiet; then
    git add -A
  fi

  if git diff --cached --quiet; then
    echo "No changes were staged after Codex attempted a fix."
    exit 1
  fi

  git commit -m "Resolve merge conflicts for ${head_ref}" -m "Co-authored-by: codex[bot] <codex[bot]@users.noreply.github.com>"
  git push origin "HEAD:${head_ref}"
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  case "$1" in
    prepare)
      [[ $# -eq 3 ]] || {
        usage
        exit 1
      }
      prepare_merge "$2" "$3"
      ;;
    finalize)
      [[ $# -eq 2 ]] || {
        usage
        exit 1
      }
      finalize_merge "$2"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
