#!/usr/bin/env bash
# Fixtures pinning scripts/ai-review.sh's contract (issue #32 test plan):
# refusal paths, prompt assembly, read-only allowlist, toplevel workspace, and
# stdout pass-through — all against a stubbed `claude`, so lint/CI catch drift
# without any API call. Style: fail fast on the first bad assertion.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
SUBJECT="$HERE/ai-review.sh"
REPO=$(git -C "$HERE" rev-parse --show-toplevel)
PROMPT_FILE="$REPO/.claude/prompts/pr-review.md"
N=0

ok() { N=$((N + 1)); }
bad() { echo "ERROR: ai-review fixture failed: $*" >&2; exit 1; }

# --- arg validation -----------------------------------------------------------
RC=0; OUT=$("$SUBJECT" 2>&1) || RC=$?
[ "$RC" -eq 2 ] || bad "no args should exit 2 (usage), got $RC"
case "$OUT" in *usage*) ok ;; *) bad "no-arg run must print usage, got: $OUT" ;; esac

RC=0; OUT=$("$SUBJECT" not-a-number 2>&1) || RC=$?
[ "$RC" -eq 1 ] || bad "non-integer PR should exit 1, got $RC"
case "$OUT" in *integer*) ok ;; *) bad "non-integer run must say 'integer', got: $OUT" ;; esac

"$SUBJECT" 0 >/dev/null 2>&1 && bad "PR 0 must be rejected" || ok

# --- refusal: outside a git repository ---------------------------------------
TMP=$(mktemp -d)
# GIT_CEILING_DIRECTORIES blocks the upward worktree search: with an exotic
# TMPDIR inside a git repo, the case must still hit the refusal, never proceed
# to invoking the real claude from make lint (round-8 💬 finding).
RC=0; OUT=$(cd "$TMP" && GIT_CEILING_DIRECTORIES="$TMP" "$SUBJECT" 7 2>&1) || RC=$?
[ "$RC" -eq 1 ] || bad "outside-repo run should exit 1, got $RC"
case "$OUT" in *git\ repository*) ok ;; *) bad "outside-repo run must name the git-repo requirement, got: $OUT" ;; esac

# --- refusal: claude not on PATH ---------------------------------------------
NOTMP=$(mktemp -d)
git -C "$NOTMP" init -q
# Deterministic absence: PATH holds ONLY bash + git (symlinked) — no claude can
# be found wherever this runs, unlike the old /usr/bin:/bin assumption (a
# machine with claude under /usr/bin made lint fail spuriously — round-1 💬
# finding; bash must be present or the subject's `#!/usr/bin/env bash`
# shebang can't resolve at all).
GITONLY=$(mktemp -d)
ln -s "$(command -v bash)" "$GITONLY/bash"
ln -s "$(command -v git)" "$GITONLY/git"
RC=0; OUT=$(cd "$NOTMP" && PATH="$GITONLY" "$SUBJECT" 7 2>&1) || RC=$?
[ "$RC" -eq 1 ] || bad "claude-less run should exit 1, got $RC"
case "$OUT" in *claude\ not\ found*) ok ;; *) bad "claude-less run must say 'claude not found', got: $OUT" ;; esac

# --- refusal: git not on PATH (message must not claim "not inside a repo") ---
BASHONLY=$(mktemp -d)
ln -s "$(command -v bash)" "$BASHONLY/bash"
RC=0; OUT=$(cd "$NOTMP" && PATH="$BASHONLY" "$SUBJECT" 7 2>&1) || RC=$?
[ "$RC" -eq 1 ] || bad "git-less run should exit 1, got $RC"
case "$OUT" in *git\ not\ found*) ok ;; *) bad "git-less run must name the missing git binary, got: $OUT" ;; esac
rm -rf "$TMP" "$NOTMP" "$GITONLY" "$BASHONLY"

# --- happy paths against a stubbed claude, invoked from a repo subdir --------
BIN=$(mktemp -d)
CAP_ARGS="$BIN/args.txt"
CAP_STDIN="$BIN/stdin.txt"
CAP_CWD="$BIN/cwd.txt"
cat >"$BIN/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CLAUDE_ARGS"
cat > "$CLAUDE_STDIN"
pwd > "$CLAUDE_CWD"
echo "STUB-REVIEW-MARKER"
STUB
chmod +x "$BIN/claude"
run_stub() { # <pr> [context...] -> captures stdout/stderr, sets RC
  STDOUT=$(cd "$HERE" && CLAUDE_ARGS="$CAP_ARGS" CLAUDE_STDIN="$CAP_STDIN" CLAUDE_CWD="$CAP_CWD" \
    PATH="$BIN:$PATH" "$SUBJECT" "$@" 2>"$BIN/err.txt") && RC=0 || RC=$?
}

# With round context: argv pinned set-wise (35 tokens: -p, --max-turns, 30,
# --settings + review-settings path, --allowedTools + 8 allowlist entries,
# --disallowedTools + 20 denied write forms — order-free so cosmetic reorders
# pass, additions/removals/typos fail).
run_stub 42 "round 1: fresh review" "round 2: verify fixes"
[ "$RC" -eq 0 ] || { cat "$BIN/err.txt"; bad "stubbed happy path should exit 0, got $RC"; }
ok
[ "$STDOUT" = "STUB-REVIEW-MARKER" ] || bad "script stdout must be exactly the review (stub sentinel), got: $STDOUT"
ok
[ -s "$BIN/err.txt" ] && bad "happy path must print nothing to stderr: $(cat "$BIN/err.txt")" || ok
LINES=$(wc -l <"$CAP_ARGS" | tr -d ' ')
[ "$LINES" -eq 35 ] || bad "claude argv should have 35 tokens, got $LINES: $(cat "$CAP_ARGS")"
ok
for token in '-p' '--max-turns' '30' '--settings' "$REPO/.claude/settings.review.json" \
  '--allowedTools' 'Read' 'Grep' 'Glob' \
  'Bash(gh pr diff *)' 'Bash(gh pr view *)' 'Bash(gh issue view *)' \
  'Bash(git log *)' 'Bash(git show *)' \
  '--disallowedTools' 'Bash(gh pr comment *)' 'Bash(gh pr edit *)' 'Bash(gh pr merge *)' \
  'Bash(gh pr create *)' 'Bash(gh pr close *)' 'Bash(gh pr ready *)' 'Bash(gh pr review *)' \
  'Bash(gh issue comment *)' 'Bash(gh issue edit *)' 'Bash(gh issue create *)' \
  'Bash(gh issue delete *)' 'Bash(gh issue develop *)' 'Bash(gh issue transfer *)' \
  'Bash(gh issue reopen *)' 'Bash(gh issue lock *)' 'Bash(gh issue unlock *)' \
  'Bash(gh issue pin *)' 'Bash(gh issue unpin *)' \
  'Bash(gh issue add-sub-issue *)' 'Bash(gh issue remove-sub-issue *)'; do
  grep -qxF -e "$token" "$CAP_ARGS" || bad "claude argv missing token: $token (got: $(cat "$CAP_ARGS"))"
  ok
done
# Prompt assembly is pinned byte-exact — deliberate format changes update this
# expectation together with the script (check-gate-query philosophy).
{
  echo "Review pull request #42 of this repository."
  echo
  cat "$PROMPT_FILE"
  echo
  echo "## Round context"
  echo "- round 1: fresh review"
  echo "- round 2: verify fixes"
} >"$BIN/expected-with-context.txt"
cmp -s "$BIN/expected-with-context.txt" "$CAP_STDIN" ||
  bad "assembled prompt mismatch (with context): $(diff "$BIN/expected-with-context.txt" "$CAP_STDIN" | head -20)"
ok
[ "$(cat "$CAP_CWD")" = "$REPO" ] || bad "agent workspace must be repo toplevel $REPO, got $(cat "$CAP_CWD")"
ok

# Without round context: no Round-context section at all.
run_stub 7
[ "$RC" -eq 0 ] || bad "stubbed no-context run should exit 0, got $RC"
ok
{
  echo "Review pull request #7 of this repository."
  echo
  # Same normalization the subject applies (command substitution strips
  # trailing newlines; printf re-adds exactly one) — pinning our assembly,
  # not the prompt file's trailing-newline hygiene.
  printf '%s\n' "$(cat "$PROMPT_FILE")"
} >"$BIN/expected-bare.txt"
cmp -s "$BIN/expected-bare.txt" "$CAP_STDIN" ||
  bad "assembled prompt mismatch (no context): $(diff "$BIN/expected-bare.txt" "$CAP_STDIN" | head -20)"
ok

# --- leading-zero PR: 08 normalizes to 8 (decimal, not octal) ------------------
run_stub 08
[ "$RC" -eq 0 ] || bad "leading-zero PR should run (08 → 8), got $RC"
ok
grep -q "Review pull request #8 of this repository." "$CAP_STDIN" ||
  bad "leading-zero PR must normalize to #8 in the prompt: $(head -1 "$CAP_STDIN")"
ok

# --- failed round: claude exits nonzero ---------------------------------------
# Must die with a clear message, never surface as an empty review (round-2 💬).
FAILBIN=$(mktemp -d)
printf '#!/usr/bin/env bash\nexit 1\n' >"$FAILBIN/claude"
chmod +x "$FAILBIN/claude"
RC=0; STDOUT=$(cd "$HERE" && PATH="$FAILBIN:$PATH" "$SUBJECT" 9 2>"$BIN/err.txt") || RC=$?
[ "$RC" -eq 1 ] || bad "failed claude round should exit 1, got $RC"
ok
grep -q "claude exited 1 —" "$BIN/err.txt" ||
  bad "failed round must explain claude's nonzero exit (with its code): $(cat "$BIN/err.txt")"
ok
[ -n "$STDOUT" ] && bad "failed round must not emit review stdout: $STDOUT" || ok

# --- silent success: claude exits 0 with no output -----------------------------
# Exit 0 + empty stdout is a failed round too, never an empty review (round-5 💬).
SILENTBIN=$(mktemp -d)
printf '#!/usr/bin/env bash\nexit 0\n' >"$SILENTBIN/claude"
chmod +x "$SILENTBIN/claude"
RC=0; STDOUT=$(cd "$HERE" && PATH="$SILENTBIN:$PATH" "$SUBJECT" 9 2>"$BIN/err.txt") || RC=$?
[ "$RC" -eq 1 ] || bad "silent claude round should exit 1, got $RC"
ok
grep -q "produced no review" "$BIN/err.txt" ||
  bad "silent round must be named a failed round: $(cat "$BIN/err.txt")"
ok
[ -n "$STDOUT" ] && bad "silent round must not emit review stdout: $STDOUT" || ok

# --- whitespace-only output: also a failed round (round-9 💬) -------------------
WSBIN=$(mktemp -d)
printf '#!/usr/bin/env bash\necho "   "\n' >"$WSBIN/claude"
chmod +x "$WSBIN/claude"
RC=0; STDOUT=$(cd "$HERE" && PATH="$WSBIN:$PATH" "$SUBJECT" 9 2>"$BIN/err.txt") || RC=$?
[ "$RC" -eq 1 ] || bad "whitespace-only claude round should exit 1, got $RC"
ok
grep -q "produced no review" "$BIN/err.txt" ||
  bad "whitespace-only round must be named a failed round: $(cat "$BIN/err.txt")"
ok

# --- prompt-file refusals: not found / not readable (round-9 💬) ---------------
NOFILE=$(mktemp -d)
git -C "$NOFILE" init -q
RC=0; OUT=$(cd "$NOFILE" && PATH="$BIN:$PATH" "$SUBJECT" 7 2>&1) || RC=$?
[ "$RC" -eq 1 ] || bad "missing prompt file should exit 1, got $RC"
ok
case "$OUT" in *prompt\ not\ found*) ok ;; *) bad "missing prompt must say 'prompt not found', got: $OUT" ;; esac
UNREADABLE=$(mktemp -d)
git -C "$UNREADABLE" init -q
mkdir -p "$UNREADABLE/.claude/prompts"
touch "$UNREADABLE/.claude/prompts/pr-review.md"
chmod 000 "$UNREADABLE/.claude/prompts/pr-review.md"
# chmod-000 only blocks non-root readers — skip (with a note) when lint runs
# as root in a devcontainer, instead of failing spuriously.
if [ "$(id -u)" -eq 0 ]; then
  echo "  note - running as root: unreadable-prompt case skipped (root reads chmod-000 files)"
else
  RC=0; OUT=$(cd "$UNREADABLE" && PATH="$BIN:$PATH" "$SUBJECT" 7 2>&1) || RC=$?
  [ "$RC" -eq 1 ] || bad "unreadable prompt file should exit 1, got $RC"
  ok
  case "$OUT" in *prompt\ not\ readable*) ok ;; *) bad "unreadable prompt must say 'prompt not readable', got: $OUT" ;; esac
fi
# --- refusal: review settings not found ----------------------------------------
# The review session must run against .claude/settings.review.json — dev-session
# settings (.claude/settings.json) allow `Bash(gh issue *)` writes. A missing
# file refuses loudly instead of falling back to the dev-session grant.
NOSET=$(mktemp -d)
git -C "$NOSET" init -q
mkdir -p "$NOSET/.claude/prompts"
: > "$NOSET/.claude/prompts/pr-review.md"
RC=0; OUT=$(cd "$NOSET" && PATH="$BIN:$PATH" "$SUBJECT" 7 2>&1) || RC=$?
[ "$RC" -eq 1 ] || bad "missing review settings should exit 1, got $RC"
ok
case "$OUT" in *review\ settings*) ok ;; *) bad "missing settings must say 'review settings', got: $OUT" ;; esac
rm -rf "$NOSET"
rm -rf "$FAILBIN" "$SILENTBIN" "$WSBIN" "$NOFILE" "$UNREADABLE" "$BIN"
echo "check-ai-review: $N assertions pass (refusals, allowlist, assembly, stdout)"
