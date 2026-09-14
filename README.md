# ai-sdlc-pilot

AI-augmented software development: AI drafts everything, humans decide everything.
Node.js backend + React frontend, built on GitHub Issues (stories) + GitHub Projects
(board) + GitHub Actions (CI/CD) + Claude Code (AI agent).

**Core principle:** AI drafts everything, humans decide everything. Every artifact
(stories, test plans, code, reviews) starts as an AI draft; every gate (approval,
merge) is a human decision.

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated with the `project` scope

## Getting started

```bash
git clone https://github.com/superdoliant/ai-sdlc-pilot.git
cd ai-sdlc-pilot
make bootstrap
make lint
make test
```

## Development workflow

See [CLAUDE.md](CLAUDE.md) for the full team conventions: story lifecycle, board
automation, Definition of Done, and the story template. In short:

```
Story flow:   idea → /story-draft → Issue [ai-draft] → HUMAN review → Ready
Dev flow:     /start-coding <n> → branch → implement → PR → AI review → HUMAN merge
Board flow:   Backlog → Ready (human) → In progress → In review → Done (all automated)
```

| Who | What |
|---|---|
| AI (Claude Code) | Drafts stories, test plans, code, reviews (advisory) |
| Human | Reviews drafts, promotes to Ready, resolves review threads, clicks merge |
| Automation | Moves board cards on git events (push, PR, merge) |

Draft your first story:
```
/story-draft "<one-paragraph feature brief>"
```

Review the draft → confirm → issue created → promote to Ready on the board → then:
```
/start-coding <issue-number>
```

## Everyday commands

```bash
make bootstrap      # install dependencies (backend/ + frontend/) and git hooks
make lint            # framework checks + ESLint (backend/ + frontend/)
make test            # backend/ + frontend/ test suites
make test-coverage   # tests with coverage report
```

Run these before pushing — CI runs the same.

## Secrets

CI and board automation rely on two GitHub Actions secrets:

| Secret | Used by | Effect when missing |
|---|---|---|
| `PROJECT_TOKEN` | board-add / story-status / story-review / story-done / story-gate | Board never moves; Ready gate stays open |
| `ANTHROPIC_AUTH_TOKEN` (+ `ANTHROPIC_BASE_URL`, `ANTHROPIC_DEFAULT_*_MODEL`) | ai-review / triage | No AI review; no failure triage |

Set with `gh secret set <NAME>`. Both skip gracefully with warnings when missing —
CI doesn't block, but the gates aren't enforced.
