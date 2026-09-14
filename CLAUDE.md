# ai-sdlc-pilot

AI-augmented software development: AI drafts everything, humans decide everything.
Node.js backend + React frontend, built on the AI-augmented SDLC framework.

## Code style

- **Backend (Node.js)**: ESLint + Prettier. Run `make lint` to check.
- **Frontend (React)**: ESLint + Prettier, with `eslint-plugin-react` /
  `eslint-plugin-react-hooks` rules enabled. Run `make lint` to check.
- Both projects share `.editorconfig` (2-space indent, LF line endings, UTF-8).

## Commands

- `make bootstrap` — `npm install` in `backend/` and `frontend/`, plus git hooks
- `make lint` — framework drift checks, then ESLint in `backend/` and `frontend/`
- `make test` — `npm test` in `backend/` and `frontend/`
- `make test-coverage` — same, with coverage reports

## Team conventions

### Workflow
- Every change starts as a GitHub Issue (story).
- Stories labeled `ai-draft` were drafted by AI and **require human review** before being worked on.
- The AI never: transitions issue state, assigns people, removes the `ai-draft` label, or closes issues.
  Board status changes come only from event-driven automation (branch push, PR link, merge) — never from the agent.
- Branches: `story/<issue#>-short-slug`. PRs to `main` only — no direct pushes.
- A PR merges only when CI (lint/test/traceability) is green, AI review threads are resolved,
  and a human approves. PR body must reference the issue ("Closes #N").
  - **AI review only runs on story PRs:** if a PR doesn't reference an issue (no "Closes #N"), 
    AI review is skipped (indicating manual/non-story code, which doesn't need AI feedback).
- Every PR from `/start-coding` runs the AI-review convergence loop before handoff: scripted
  rounds (`scripts/ai-review.sh <pr> "round N: …"`) iterate fix → re-review until the verdict
  is "no blocking concerns". The loop is procedural via `/start-coding`;
  `ai-review.yml` remains the per-push CI backstop. Findings stay advisory — humans decide.
- A story's lifecycle is terminal at Done: follow-up work on a merged story gets its own
  issue; board automation ignores pushes to a closed story's branch.
- Implementation starts only via `/start-coding <n>` — the single entry point. It checks
  the card's board Status mechanically and stops unless the story is Ready (or In progress
  when resuming); Backlog and unboarded stories are refused. `Ready` is the one lock: the
  `test plan approved` comment is no longer a gate — `/test-plan` drafts an aid that gets
  reviewed as part of card review. CI backs the gate up — Backlog → In progress is
  refused on branch push, and PRs do not move Backlog cards to In review.

### Board lifecycle
Status moves are automatic consequences of verifiable events — the only manual move is the first one:
- **Ready** — a human promotes the story after review
- **In progress** — first push of the `story/<issue#>-*` branch (`.github/workflows/story-status.yml`) — Ready stories only: a Backlog card is refused until a human promotes it
- **In review** — a non-draft PR closes the story (on open, or on a body edit that adds the closing ref — `.github/workflows/story-review.yml`)
- **Done** — a PR closing the story merges (`.github/workflows/story-done.yml`); the issue auto-closes (GitHub built-in). A story closed as completed without a merge is healed to Done by the next story-done run — closed-as-completed means Done, however it closed. (Healing covers carded stories; never-boarded closed stories are a known edge case — see story-done.yml comments.)

### Definition of Done
A story is done when its PR merges, and all of the following held at merge time:
1. Every acceptance criterion has a passing test, traceable via the test plan
2. The story was human-promoted to Ready before implementation started (the `/start-coding` gate)
3. `lint`, `test`, and `traceability` CI checks are green
4. All AI review threads are resolved, or explicitly dismissed with a reason
5. A human clicked merge
6. The story's own lifecycle fired — the board shows its trail (Backlog → … → Done)
Merge closes the issue and moves the board item to Done automatically.

### Story template (required — used by /story-draft)
Every story contains these sections:
- **Context** — the problem/opportunity, 2-4 sentences
- **User story** — "As a \<role\>, I want \<capability\>, so that \<benefit\>."
- **Acceptance criteria** — Given/When/Then bullets, each independently testable
- **Edge cases & error handling** — at least 3
- **Out of scope** — explicitly excluded
- **Open questions** — what a human must decide before Ready
- **Testability notes** — risk areas the test plan should focus on

### Commands
- `make bootstrap` — install dependencies and git hooks
- `make lint` / `make test` — must pass locally before pushing
- `gh issue list --state all` — see the backlog
- `gh issue view <n>` — read a story

## Architecture map

```
<project>/
├── .claude/                    # Claude Code: workflow commands + prompts
│   ├── commands/               # /init-sdlc, /story-draft, /story-refine,
│   │                           # /story-status, /test-plan, /gen-tests, /start-coding
│   ├── prompts/pr-review.md    # AI review instructions (advisory output)
│   ├── settings.json           # dev-session permissions
│   └── settings.review.json    # review-session minimal permissions (read-only)
├── scripts/
│   ├── ai-review.sh            # scripted AI-review round (read-only tool grants)
│   ├── ai-review.fixture.sh    # pins ai-review.sh's contract (no API call)
│   └── heal-filter.jq          # story-done heal-sweep filter (fixture-pinned)
├── .github/
│   ├── actions/project-lookup/  # shared board project/field/option lookup
│   ├── workflows/               # board automation + CI gates
│   └── branch-protection.json   # branch protection rules (applied by /init-sdlc)
├── docs/test-plans/             # per-story test plans (issue-N-test-plan.md)
├── backend/                     # Node.js backend
│   ├── src/
│   └── package.json
└── frontend/                    # React frontend
    ├── src/
    └── package.json
```

Board lifecycle is event-driven — the only manual move is the human Ready
promotion: `board-add` (story → Backlog), `story-status` (story/* branch push →
In progress, Ready-gated), `story-review` (non-draft PR closing the story → In
review), `story-done` (merge → Done + heal sweep).

CI gates live in `.github/workflows/ci.yml` (lint / test / traceability /
story-gate / conventions / triage); `ai-review.yml` is the per-push AI review
backstop. AI output is advisory everywhere — humans promote Ready and click
merge.
