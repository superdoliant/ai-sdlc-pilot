---
description: Initialize a new project with the AI-augmented SDLC framework — repo, board, labels, branch protection, and all template files
argument-hint: <project name in quotes>
---
You are setting up a brand-new project with the AI-augmented SDLC framework. This is
a multi-phase guided setup — confirm with the user before each phase that changes
external state. Never skip a phase or proceed after a failure.

## Phase 1 — Collect information (questionnaire)

Present a form with all fields upfront. User provides all answers at once in one batch,
then proceed non-blocking (no more prompts). Collect:

1. **Project name** — use $ARGUMENTS if provided, else prompt once
2. **Description** — show example, allow blank for default
3. **GitHub owner** — default: infer from `gh api user -q .login`
4. **Team lead** — default: same as owner
5. **Repo visibility** — public (default) or private (warn about limitations)
6. **Backend stack** — spring-boot / nodejs / python / go / none / other (default: nodejs)
7. **Frontend stack** — flutter / react / vue / angular / none / other (default: react)

Example flow:
```
=== AI-Augmented SDLC Project Setup ===

Project name: sdlc-verification
Description [AI-augmented software development...]: 
GitHub owner [leojiang]: 
Team lead [leojiang]: 
Visibility - public or private? [public]: public
Backend stack - spring-boot/nodejs/python/go/none/other [nodejs]: nodejs
Frontend stack - flutter/react/vue/angular/none/other [react]: react

=== Configuration Summary ===
Project: sdlc-verification
Description: AI-augmented software development...
Owner: leojiang
Team lead: leojiang
Visibility: public
Backend: nodejs
Frontend: react

Proceeding with setup...
```

Once all inputs collected and confirmed, proceed with Phases 2-11 without interruption.

**Why defaults?**
- 90% of users will choose Node.js + React anyway
- Public repos are required for the framework to work properly
- The owner is already authenticated (gh would fail if not)
- Generic description is fine; users customize later in their README
- This keeps the command fast and non-interactive

## Phase 2 — Prerequisites check

Verify each prerequisite. For any failure, print the fix command and STOP — do not
continue with a broken environment.

1. `git --version` — must exist
2. `gh --version` — must exist
3. `gh auth status` — must be authenticated; check output for `project` scope.
   If missing: tell the user to run `gh auth refresh -h github.com -s project`
   and STOP.
4. `jq --version` — required by board workflows
5. Stack-specific checks (only for the chosen stacks):
   - Spring Boot → `java -version` (JDK 17+)
   - Flutter → `flutter --version` (stable channel)
   - Node.js → `node --version` (18+)
   - Python → `python3 --version` (3.10+)
   - Go → `go version` (1.21+)

## Phase 3 — GitHub repository setup

1. Check if already in a git repo with a GitHub remote:
   `git remote get-url origin 2>/dev/null`
   - **Has remote**: confirm with user: "Use existing repo <owner/repo>?"
   - **No remote or no git repo**: initialize and create:
     ```
     git init   (only if not already a repo)
     gh repo create <owner>/<project-name> --source . --<visibility> --push
     ```
2. Verify the remote exists: `gh repo view --json nameWithOwner -q .nameWithOwner`
   If this fails, STOP.
3. Store the repo coordinates for later steps:
   ```
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
   OWNER=${REPO%/*}; REPO_NAME=${REPO#*/}
   ```

## Phase 4 — Generate and customize framework files

This is the core of the command. Tell the user you're about to write the framework
files and confirm before proceeding.

### 4a. Files that are fully generic (write as-is from the current repo)

These files are already correct in the template repo and need no modification. If any
are missing (e.g. the user started from a clean clone and deleted them), regenerate
them exactly as they exist in this repo:

- `.claude/commands/story-draft.md`
- `.claude/commands/story-refine.md`
- `.claude/commands/story-status.md`
- `.claude/commands/test-plan.md`
- `.claude/commands/start-coding.md`
- `.claude/commands/gen-tests.md`
- `.claude/prompts/pr-review.md`
- `.claude/settings.json`
- `.claude/settings.review.json`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/actions/project-lookup/action.yml`
- `.github/workflows/ai-review.yml`
- `scripts/ai-review.sh`
- `scripts/ai-review.fixture.sh`
- `scripts/heal-filter.jq`
- `scripts/heal-filter.fixture.json`
- `.pre-commit-config.yaml` (the gitleaks base)
- `.github/branch-protection.json` (rules applied in Phase 8)

### 4b. Project-title substitution (4 board workflow files)

In each of these files, replace the `PROJECT_TITLE` env value with the user's project
name (the value that will match the GitHub Project title created in Phase 5):

- `.github/workflows/board-add.yml` — change `PROJECT_TITLE: SDLC Pilot` to `PROJECT_TITLE: <project name>`
- `.github/workflows/story-status.yml` — same substitution
- `.github/workflows/story-review.yml` — same substitution
- `.github/workflows/story-done.yml` — same substitution

Also in `.github/workflows/ci.yml`, the `story-gate` job has `PROJECT_TITLE: SDLC Pilot` — replace it too.

### 4c. Stack-adaptive files (generate based on chosen stack)

**Before generating**, confirm the tech stack choices with the user:

Show them what was selected in Phase 1:
```
Backend stack: <backend choice>
Frontend stack: <frontend choice>

Is this correct? (yes/no)
```

If they say "no", go back and ask them to re-confirm their choices from Phase 1.

If they say "yes", proceed to generate the following files using Claude:

For each file below, invoke Claude with a detailed prompt to generate content adapted 
to the user's chosen backend and frontend stack. Use the existing file as a structural 
reference but replace stack-specific parts. If the user chose "Other" for either stack, 
use `# ADAPT` comment markers with clear instructions for what to fill in.

Then show the user the generated file and ask: **"Does this look right?"** 
- If yes: write it to disk
- If no: ask what's wrong and regenerate

**`Makefile`** — Invoke Claude with this prompt:

```
Generate a Makefile for a <backend> backend + <frontend> frontend project.
Include these targets:
- bootstrap: install dependencies (pre-commit hook setup + language-specific)
- lint: run code style checks
- test: run test suite
- test-coverage: run tests with coverage report

Also include these framework-level drift checks (DO NOT modify, copy exactly):
[INSERT the check-gate-query, check-ai-review, check-ai-review-tools, check-review-settings 
targets from the current Makefile]

For <backend> + <frontend>, use these commands:

Backend (<backend>):
  - bootstrap: [command]
  - lint: [command]
  - test: [command]
  - test-coverage: [command]

Frontend (<frontend>):
  - bootstrap: [command]
  - lint: [command]
  - test: [command]
  - test-coverage: [command]

If both are present, each target should run backend first, then frontend (use shell if logic).
If one is "None", skip that section.
If one is "Other", add # ADAPT comments with placeholders.

Output the complete Makefile.
```

Reference table for common stacks:

| Stack | bootstrap | lint | test | test-coverage |
|---|---|---|---|---|
| Spring Boot | `./mvnw dependency:go-offline compile` | `./mvnw -DskipTests compile` | `./mvnw test` | `./mvnw verify jacoco:report` |
| Node.js | `npm install` | `npm run lint` | `npm test` | `npm test -- --coverage` |
| Python (FastAPI) | `pip install -e ".[dev]"` | `ruff check . && ruff format --check .` | `pytest` | `pytest --cov` |
| Flutter | `flutter pub get` | `flutter analyze` | `flutter test` | `flutter test --coverage` |
| Go | `go mod download` | `go vet ./...` | `go test ./...` | `go test -coverprofile=coverage.out ./...` |

**`CLAUDE.md`** — Invoke Claude:

```
Rewrite CLAUDE.md for the <project name> project using <backend> backend + <frontend> frontend.

Keep these sections EXACTLY as they are (do not modify):
- Team conventions / Workflow
- Board lifecycle
- Definition of Done
- Story template

Customize:
- Project title: <project name>
- Project description: <description from Phase 1>
- Code style section: generate rules for the chosen stack
  (e.g., Java: Google Java Format, Node.js: ESLint + Prettier, Python: ruff, Flutter: flutter analyze)
- Commands section: document `make bootstrap`, `make lint`, `make test`, describing what they do for this stack
- Architecture map: show a starter directory tree for the chosen stack
  (e.g., src/main/java/... for Spring Boot, src/ for Node, lib/ for Flutter)

Output the complete CLAUDE.md file.
```

**`.editorconfig`** — Invoke Claude:

```
Generate a .editorconfig file for <backend> + <frontend> project.

Keep the generic root block: charset=utf-8, end_of_line=lf, insert_final_newline=true

Add language-specific sections:
- [*.java]: indent_size=4 (for Spring Boot)
- [*.js,*.ts,*.jsx,*.tsx]: indent_size=2 (for Node.js)
- [*.py]: indent_size=4 (for Python)
- [*.dart]: indent_size=2 (for Flutter)
- [*.go]: indent_style=tab (for Go)
- [Makefile]: indent_style=tab (always required)

Only include sections for the chosen stacks.

Output the complete .editorconfig file.
```

**`.gitignore`** — Invoke Claude:

```
Generate a .gitignore file for <backend> + <frontend> project.

Always include: .env*, .DS_Store, *.log, .idea/, .vscode/, *.iml

Add stack-specific patterns:
- Spring Boot: target/, *.class, .mvn/, mvnw.cmd
- Node.js: node_modules/, dist/, build/, coverage/
- Python: __pycache__/, *.pyc, .venv/, venv/, dist/, build/
- Flutter: build/, .dart_tool/, .flutter-plugins
- Go: go.mod.tidy result, vendor/ (if used)

Only include patterns for the chosen stacks.

Output the complete .gitignore file.
```

**`.github/workflows/ci.yml`** — Invoke Claude:

```
Adapt the ci.yml workflow for <backend> + <frontend> project.

Keep these jobs EXACTLY as they are:
- traceability
- story-gate
- conventions
- triage

Customize the `lint` and `test` jobs:
- Add stack-specific setup actions:
  - Spring Boot: actions/setup-java@v4 with temurin 17
  - Node.js: actions/setup-node@v4 with node 20
  - Python: actions/setup-python@v5 with python 3.12
  - Flutter: subosito/flutter-action@v2 + actions/setup-java@v4
  - Go: actions/setup-go@v5

- Update the run commands to use `make lint`, `make test`, `make bootstrap`
- Adapt the coverage artifact path (if applicable):
  - Spring Boot: target/site/jacoco/
  - Node.js: coverage/
  - Python: htmlcov/
  - Flutter: coverage/
  - Go: coverage.out (if using go test -coverprofile)

Remove Flutter-specific env vars (PUB_HOSTED_URL, check-pub-host) unless Flutter is chosen.

Output the complete ci.yml file with all jobs.
```

**`README.md`** — Invoke Claude:

```
Generate a new README.md for the <project name> project with <backend> + <frontend> stack.

Include:
- Project title: <project name>
- Project description: <description from Phase 1>
- Prerequisites section for the chosen stack (what tools/versions to install)
- Getting started: git clone, make bootstrap, make lint, make test
- Development workflow: brief summary linking to CLAUDE.md
- Secrets section: mention PROJECT_TOKEN and ANTHROPIC_AUTH_TOKEN
- Link to CLAUDE.md for detailed conventions and workflow

Output the complete README.md file.
```

Then show each generated file to the user and ask: **"Does [filename] look correct?"**
- If yes for all: write them all to disk
- If no for any: ask what needs to change and regenerate that file

### 4d. Username substitution

**`.github/CODEOWNERS`** — Write `* @<team-lead-username>` using the value from Phase 1.

### 4e. Optional files

**`.github/ISSUE_TEMPLATE/story.yml`** — Create the story intake form for non-developers:
```yaml
name: Story brief
description: Raw brief — AI will expand it into a full story draft
labels: [story, ai-draft, needs-expansion]
body:
  - type: textarea
    id: brief
    attributes:
      label: Feature brief
      description: The problem or opportunity, in plain language
    validations:
      required: true
  - type: textarea
    id: context
    attributes:
      label: Constraints / context
      description: Deadlines, dependencies, must-nots
```

**`docs/test-plans/.gitkeep`** — Create the empty directory.

## Phase 5 — Clean up non-framework content

Check for and remove any files that don't belong to the framework. The template
repo ships clean, but users who forked an older version may have leftover files.

If any of the following exist, delete them (skip silently if absent):
- `backend/`, `frontend/` directories (leftover scaffolds from the pilot)
- `docs/test-plans/issue-*.md` (pilot-specific test plans)
- `docs/screenshots/` directory
- `ONBOARDING.md`
- `.claude/settings.local.json` (machine-specific, not part of template)
- Any `.idea/` directories or `*.iml` files

Also remove any other files the user doesn't recognize as theirs — ask before
deleting anything unexpected.

Do NOT delete:
- `.claude/commands/init-sdlc.md` (this command itself — useful for reference)
- Any file listed in Phase 4 sections a-d
- The `.git/` directory

## Phase 6 — Commit and push (MUST happen before project board creation)

The GitHub Project board needs a committed and pushed repository to link to.
The board will not connect properly if the repo hasn't been pushed to remote yet.

1. Verify the framework files are ready:
   ```bash
   make lint
   ```
   If lint fails, fix the issues before proceeding.

2. Stage and commit:
   ```bash
   git add -A
   git commit -m "bootstrap: AI-augmented SDLC framework for <project-name>"
   ```

3. Push to remote:
   ```bash
   git push -u origin main
   ```

If the push fails, STOP and ask the user to fix authentication/permissions issues.

## Phase 7 — Create GitHub Project board

Tell the user: "I'm about to create a GitHub Project board and link it to your repo.
This requires the `project` scope on your gh token." Confirm before proceeding.

1. Create the project:
   ```
   gh project create --owner <owner> --title "<project name>" --format json
   ```
   Parse the project number from the JSON output.

2. Create the Status field with all required options:
   ```
   gh project field-create <number> --owner <owner> --name "Status" --data-type "SINGLE_SELECT" --single-select-options "Backlog,Ready,In progress,In review,Done"
   ```

3. Link the project to the repository:
   ```
   gh project link <number> --owner <owner> --repo <owner>/<repo-name>
   ```

4. Verify: `gh project field-list <number> --owner <owner> --format json`
   Check that the Status field exists with all 5 options.

If any step fails, show the error and the manual alternative (go to
github.com → Projects → New project → add Status field manually). Do not STOP the
whole init — the rest of the setup can proceed without the board, though board
automation won't fire until it's configured.

5. **Configure Board view with Status columns (manual step).**
   Print clear instructions for the user:

   > **Manual step required — configure the board view:**
   > 1. Go to your GitHub Project board
   > 2. Click the **View** dropdown (top toolbar) → Select **Board** (instead of Table)
   > 3. Once in Board view, click **Group by** (top toolbar) → Select **Status**
   > 4. Verify the columns appear: Backlog | Ready | In progress | In review | Done
   >
   > The board must be in Board view grouped by Status for the automation to work.
   > Without this configuration, the workflow automation won't move cards between columns.

6. **Disable built-in project workflows that race our custom automation.**
   The GitHub Projects API does not support toggling built-in workflows, so print
   clear manual instructions for the user:

   > **Important — manual step required:**
   > Go to your project board → **⋯** menu (top right) → **Settings** → **Workflows** and:
   > - **Disable** "Pull request linked to issue" — our `story-review.yml` handles this with a Ready gate
   > - **Disable** "Pull request merged" — our `story-done.yml` handles this deterministically with a heal sweep
   > - **Keep enabled**: "Item added to project", "Item closed", "Auto-close issue"
   >
   > If the built-in workflows stay on, they race our custom workflows and can
   > move cards to the wrong status.

   Also query the project's current workflow state to confirm what needs changing.
   Try the organization query first; if the owner is a personal account, fall back
   to the user query (same pattern as `project-lookup/action.yml`):
   ```
   gh api graphql -f query='query($login: String!, $n: Int!) {
     organization(login: $login) { projectV2(number: $n) {
       workflows(first: 20) { nodes { name enabled } }
     } }
   }' -f login=<owner> -F n=<project-number>
   ```
   If that errors (not an org), retry with `user(login: ...)` instead.
   Show the user the current state so they can see exactly which toggles to flip.

## Phase 8 — Create labels

Create the 4 required labels (skip with a note if they already exist — `gh label create`
errors on duplicates, so check first with `gh label list --json name -q '.[].name'`):

```
gh label create story          --description "User story"                     --color 0E8A16
gh label create ai-draft       --description "AI-drafted; needs human review" --color D4C5F9
gh label create needs-expansion --description "Raw brief; CI will expand it"  --color FBCA04
gh label create flaky          --description "Quarantined flaky test"         --color F9D0C4
```

## Phase 9 — Branch protection (public repos only)

Branch protection rules are stored in `.github/branch-protection.json` — the single
source of truth. This file mirrors the pilot repo's proven settings: required status
checks (lint, test, story-gate), enforce admins, dismiss stale reviews, required linear
history, required conversation resolution, no force pushes, no deletions.

Branch protection rules are stored in `.github/branch-protection.json` — the single
source of truth. This file mirrors the pilot repo's proven settings: required status
checks (lint, test, story-gate), enforce admins, dismiss stale reviews, required linear
history, required conversation resolution, no force pushes, no deletions.

If the repo is **private**, skip this phase and print:
> Branch protection requires GitHub Pro/Team for private repos. The rules are saved
> in `.github/branch-protection.json` — apply them manually after upgrading, or switch
> to a public repo. The workflow's other enforcement layers (CI checks, `/start-coding`
> gate, board automation) still work without branch protection.

If the repo is **public**, confirm with the user, then apply the protection rules:

```
gh api repos/<owner>/<repo-name>/branches/main/protection -X PUT \
  -H "Accept: application/vnd.github+json" \
  --input .github/branch-protection.json
```

After applying, verify:
```
gh api repos/<owner>/<repo-name>/branches/main/protection
```

If this fails (e.g., insufficient permissions), print the contents of
`.github/branch-protection.json` as a manual checklist and continue.

The user can customize the rules later by editing `.github/branch-protection.json`
and re-applying with the same `gh api` command.

## Phase 10 — Secrets setup

Secrets are required for board automation and AI review. Walk through each one
interactively — ask the user for the value, then set it. Do NOT skip ahead without
asking. For each secret, explain what it is, then ask the user to provide the value
(or say "skip" to defer).

**Important:** You cannot read or echo secret values. Use `gh secret set <NAME>` which
reads from stdin. When the user provides a value, pipe it directly:
```
echo "<value>" | gh secret set <NAME>
```

### 10a. PROJECT_TOKEN (required for board automation)

Tell the user:
> The board workflows need a GitHub Personal Access Token with the `project` scope to
> move cards between statuses. Without it, the board won't update automatically.
>
> Create one at: **github.com → Settings → Developer settings → Personal access tokens
> → Tokens (classic) → Generate new token**
> - Name: something like "SDLC board automation"
> - Scopes: check **`project`** (also **`repo`** if the repo is private)
> - Copy the token — you won't see it again

Then ask: "Paste your PROJECT_TOKEN (or type 'skip' to set it later):"

- If the user provides a value:
  ```
  echo "<value>" | gh secret set PROJECT_TOKEN
  ```
  Then verify with `gh secret list`. If `PROJECT_TOKEN` appears in the output, confirm success. If not, show an error: "Failed to set PROJECT_TOKEN — please check the value and try again."
- If the user says "skip": note that board automation won't work until this is set,
  and continue.

### 10b. ANTHROPIC_AUTH_TOKEN (required for AI review + triage)

Tell the user:
> The AI review and failure triage CI jobs need an API key for the AI model endpoint.
> This is your Anthropic API key, or the token for a compatible endpoint (e.g., GLM).

Then ask: "Paste your ANTHROPIC_AUTH_TOKEN (or type 'skip' to set it later):"

- If the user provides a value:
  ```
  echo "<value>" | gh secret set ANTHROPIC_AUTH_TOKEN
  ```
  Then verify with `gh secret list`. If `ANTHROPIC_AUTH_TOKEN` appears, confirm success. If not, show an error and ask them to try again.
- If the user says "skip": note that AI review and triage won't run until this is set.

### 10c. ANTHROPIC_BASE_URL (optional — non-Anthropic endpoints only)

Always ask this:

Tell the user:
> If you're using Anthropic's API directly, skip this. If using a compatible endpoint
> (e.g., GLM, or a local proxy), provide the base URL.

Ask: "Paste your ANTHROPIC_BASE_URL (or type 'skip' if using Anthropic directly):"

- If the user provides a URL: `echo "<value>" | gh secret set ANTHROPIC_BASE_URL`
  Then verify with `gh secret list`. Proceed to Phase 10d.
- If skip: continue to Phase 11 (skip Phase 10d).

### 10d. Model overrides (optional — custom endpoints only)

Only ask this if the user set ANTHROPIC_BASE_URL in Phase 10c (didn't skip it).

Tell the user:
> Some endpoints use different model names. If your endpoint remaps model IDs,
> provide them here. Otherwise, the defaults from Anthropic will be used.

Ask for each model (user can skip any):
- "Model ID for Claude Sonnet (or 'skip'):"
- "Model ID for Claude Haiku (or 'skip'):"
- "Model ID for Claude Opus (or 'skip'):"

For each one provided:
- `echo "<value>" | gh secret set ANTHROPIC_DEFAULT_SONNET_MODEL`
- `echo "<value>" | gh secret set ANTHROPIC_DEFAULT_HAIKU_MODEL`
- `echo "<value>" | gh secret set ANTHROPIC_DEFAULT_OPUS_MODEL`

If all are skipped or user skipped ANTHROPIC_BASE_URL, proceed to Phase 11.

### 10e. Summary

After all secrets are handled, run `gh secret list` and show the user which secrets
are configured. For any that were skipped, remind them:
> To set a secret later: `gh secret set <NAME>` (paste the value when prompted).
> Board workflows and AI review skip gracefully when secrets are missing — they
> emit warnings but don't block CI.

## Phase 11 — Verification and next steps

Run final verification:
- `gh project list --owner <owner>` — should show the board
- `gh label list` — should show all 4 labels
- If public: `gh api repos/<owner>/<repo>/branches/main/protection` — should return the rules

Print the **"What's next"** summary:
```
✅ Project "<project name>" is set up with the AI-augmented SDLC framework.

Secrets to configure (if not done above):
  gh secret set PROJECT_TOKEN        # PAT with project scope — board automation
  gh secret set ANTHROPIC_AUTH_TOKEN  # AI model API key — AI review + triage

Your first story:
  claude
  > /story-draft "<one-paragraph feature brief>"
  # Review the draft → confirm → issue created with story + ai-draft labels
  # Go to the Project board → promote the card from Backlog to Ready

Start coding:
  > /start-coding <issue-number>
  # Gate-checks Ready → syncs main → branches → implements → opens PR

Everyday commands:
  make lint          # must pass before pushing
  make test          # must pass before pushing
  /story-status <n>  # check where a story stands on the board
```

Never: create issues, draft stories, or start implementation during init. The setup
is complete when the framework files are committed and the GitHub resources exist.
