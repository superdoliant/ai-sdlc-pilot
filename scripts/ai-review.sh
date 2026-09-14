#!/usr/bin/env bash
# Scripted AI review — the reproducible invocation behind /start-coding's
# convergence loop (story #32). The ad-hoc hand-typed form lived only in session
# memory and drifted (the #30 gate-query brace was a hand-copying cost); this
# file is the single source. Round context (optional args) is appended verbatim
# so later rounds can verify earlier fixes — the invocation itself never changes
# shape between rounds.
#
# Usage: scripts/ai-review.sh <pr-number> [round-context...]
# Blocking; prints the review markdown to stdout. The allowlist below is
# read-only, and the review session runs against its own minimal-permission
# settings (.claude/settings.review.json via --settings), so the dev-session
# project settings (.claude/settings.json allows `Bash(gh issue *)`) cannot
# widen the review grant beyond --disallowedTools' write-denials; user-level
# settings can never be fully excluded — review output is advisory either way.
# Scope: same-repo PRs — the /start-coding path pushes story branches to origin
# and opens PRs from them, so a fork PR never reaches this script; CI's
# ai-review.yml is the layer that refuses fork-authored content.
set -euo pipefail
# Without errexit inheritance a cat failure inside the $(…) prompt assembly
# below can be masked by the trailing echo on older bash; no-op where
# unsupported (introduced in bash 4.4 — macOS stock 3.2 is in the no-op
# range), where the -r pre-check remains the guard.
shopt -s inherit_errexit 2>/dev/null || true

die() { echo "ERROR: $*" >&2; exit 1; }
usage() { echo "usage: scripts/ai-review.sh <pr-number> [round-context...]" >&2; }

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
  exit 2
fi
case "$1" in
  '' | *[!0-9]*) die "PR number must be an integer, got: $1" ;;
esac
PR=$((10#$1)) # force decimal — 08 is 8, not invalid octal, so the -ge below stays valid
[ "$PR" -ge 1 ] || die "PR number must be >= 1, got: $PR"
shift

# The review prompt is repo-relative, and the agent's workspace root should be
# the repo toplevel however deep the caller sits.
command -v git >/dev/null 2>&1 ||
  die "git not found on PATH — ai-review.sh needs git to locate the repo"
TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null) ||
  die "not inside a git repository — run from a checkout of the repo (the review prompt lives at .claude/prompts/pr-review.md)"
command -v claude >/dev/null 2>&1 ||
  die "claude not found on PATH — install Claude Code before running the review loop"

PROMPT_FILE="$TOPLEVEL/.claude/prompts/pr-review.md"
[ -f "$PROMPT_FILE" ] || die "review prompt not found: $PROMPT_FILE"
[ -r "$PROMPT_FILE" ] || die "review prompt not readable: $PROMPT_FILE"
SETTINGS_FILE="$TOPLEVEL/.claude/settings.review.json"
[ -r "$SETTINGS_FILE" ] || die "review settings not found or not readable: $SETTINGS_FILE"
cd "$TOPLEVEL"

# Assemble first, pipe only claude: an assembly failure (e.g. cat dying on a
# file that lost readability between the check and here) must abort with its
# own message, never leak into the pipeline where the die below would
# misattribute it as a claude failure.
PROMPT=$(
  {
    echo "Review pull request #$PR of this repository."
    echo
    cat "$PROMPT_FILE"
    if [ $# -gt 0 ]; then
      echo
      echo "## Round context"
      for ctx in "$@"; do
        echo "- $ctx"
      done
    fi
  }
) || die "prompt assembly failed — cannot read $PROMPT_FILE"
RC=0
REVIEW=$(printf '%s\n' "$PROMPT" | claude -p --max-turns 30 \
  --settings "$SETTINGS_FILE" \
  --allowedTools "Read" "Grep" "Glob" \
  "Bash(gh pr diff *)" "Bash(gh pr view *)" "Bash(gh issue view *)" \
  "Bash(git log *)" "Bash(git show *)" \
  --disallowedTools "Bash(gh pr comment *)" "Bash(gh pr edit *)" "Bash(gh pr merge *)" \
  "Bash(gh pr create *)" "Bash(gh pr close *)" "Bash(gh pr ready *)" "Bash(gh pr review *)" \
  "Bash(gh issue comment *)" "Bash(gh issue edit *)" "Bash(gh issue create *)" \
  "Bash(gh issue delete *)" "Bash(gh issue develop *)" "Bash(gh issue transfer *)" \
  "Bash(gh issue reopen *)" "Bash(gh issue lock *)" "Bash(gh issue unlock *)" \
  "Bash(gh issue pin *)" "Bash(gh issue unpin *)" \
  "Bash(gh issue add-sub-issue *)" "Bash(gh issue remove-sub-issue *)") ||
  RC=$?
if [ "$RC" -ne 0 ]; then
  die "claude exited $RC — the review round failed; there is no review to evaluate (auth failure, flag rejection, and crash are distinguishable only by this code)"
fi
[ -n "${REVIEW//[[:space:]]/}" ] ||
  die "claude exited 0 but produced no review — a failed round, never an empty one"
printf '%s\n' "$REVIEW"
