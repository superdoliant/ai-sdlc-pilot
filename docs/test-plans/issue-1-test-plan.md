# Test plan — Issue #1: Reset README.md to empty placeholder

Story: https://github.com/superdoliant/ai-sdlc-pilot/issues/1

## Objective

Verify that `README.md` is reduced to a minimal placeholder (no stale setup/workflow
content) without breaking CI, other docs' cross-references, or file-handling tooling
(`pre-commit`, GitHub's renderer). This is a docs-only change — no application code
exists yet (`backend/`, `frontend/` are unscaffolded), so there is no unit-test layer
for this story; verification is by inspection and by running the existing CI gates
unmodified.

## Traceability

| Acceptance criterion | Planned test(s) | Layer |
|---|---|---|
| `README.md` exists at repo root with no body content (or only a single `# ai-sdlc-pilot` heading) | Inspect file content post-change (`cat README.md`); confirm it matches the confirmed scope (heading-only, per Open Questions resolution) | Manual inspection |
| `make lint` and `make test` still pass after emptying README | Run `make lint` and `make test` locally before pushing; CI `lint`/`test` jobs re-verify on the PR | CI (existing `lint`/`test` jobs, unmodified) |
| No stale/inaccurate setup instructions remain on GitHub's rendered view | Diff old vs. new `README.md`; grep repo docs (`CLAUDE.md`, `.github/*.md`) for links/references into README sections being removed | Manual inspection + `grep` |

## Risk-based priority

- **Highest risk: dangling cross-references.** `CLAUDE.md` and `.github/PULL_REQUEST_TEMPLATE.md`
  may reference README sections (e.g., "see README for setup"). Test hardest here —
  a broken doc link is worse than a blank README, since it actively misleads.
- **Medium risk: tooling edge cases on empty files.** `.editorconfig`'s
  `insert_final_newline = true` and any `pre-commit` hooks (gitleaks, trailing
  whitespace) could behave oddly on a zero-byte file. Test with the actual chosen
  format (heading-only avoids this risk entirely; true zero-byte does not).
- **Low risk: CI breakage.** `make lint`/`make test` don't inspect README content, so
  this is a sanity check, not a real risk area.

## Negative and boundary cases

- Zero-byte `README.md` (no trailing newline at all) — verify `pre-commit`'s
  `end-of-file-fixer`/`insert_final_newline` behavior doesn't reject or silently
  rewrite it in a way that surprises the next commit.
- `README.md` with only whitespace/newlines and no heading — verify GitHub's file
  browser renders this without error (empty preview is acceptable; a rendering error
  is not).
- A doc elsewhere in the repo linking to a specific README anchor (`README.md#getting-started`)
  that no longer exists post-change — grep confirms whether any such anchor links exist
  before merging.

## Test data / environment

- No test data or special environment needed — this is a single static file change
  verified by direct inspection and the existing CI pipeline (GitHub Actions, `ubuntu-latest`).
- Stays fully manual: content correctness (does the new README match the agreed
  "empty" definition) is a human judgment call, not something to automate.
- Automated: `make lint` / `make test` via existing CI jobs (no new test code needed).

## Open item carried from the story

The story's own Open Questions (exact definition of "empty," and the rationale for
discarding the current README) are unresolved. This plan assumes the reviewer resolves
them during card review; if the resolution changes the acceptance criteria materially
(e.g., zero-byte vs. heading-only), the traceability table's first row should be
re-checked against whichever definition is confirmed.
