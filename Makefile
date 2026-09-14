.PHONY: bootstrap lint test test-coverage

# Node.js backend + React frontend, each in its own directory.

bootstrap:
	@command -v pre-commit >/dev/null && pre-commit install || true
	@if [ -f backend/package.json ]; then cd backend && npm install; else echo "backend/ has no package.json yet — skipping (run npm init in backend/ to add your backend)"; fi
	@if [ -f frontend/package.json ]; then cd frontend && npm install; else echo "frontend/ has no package.json yet — skipping (scaffold your React app in frontend/)"; fi

# Framework-level drift checks — these are stack-agnostic and must always run.
# The board-gate GraphQL query is deliberately duplicated: start-coding.md runs it,
# story-status.md documents it as the read-only inspection. Hand-copying a ~300-char
# line drifted once (#30 review round 3: one extra closing brace — the command then
# could not execute its own gate). Fail on any drift so the copies can only change
# together, byte-identical.
.PHONY: check-gate-query
check-gate-query:
	@a=$$(grep '^   gh api graphql' .claude/commands/story-status.md | sed 's/^ *//'); \
	 b=$$(grep '^   gh api graphql' .claude/commands/start-coding.md | sed 's/^ *//'); \
	 if [ -z "$$a" ] || [ -z "$$b" ]; then \
	   echo "ERROR: check-gate-query could not find the gate query in both command files"; \
	   exit 1; \
	 fi; \
	 if [ "$$a" != "$$b" ]; then \
	   echo "ERROR: the board-gate query drifted between story-status.md and start-coding.md"; \
	   echo "       (#30 round 3 shipped an extra brace this way). Update both together."; \
	   exit 1; \
	 fi; \
	 echo "check-gate-query: gate query copies identical"

# scripts/ai-review.sh is the scripted half of /start-coding's AI-review
# convergence loop (#32) — its invocation must never drift (the ad-hoc
# hand-typed form did; see the story's context). Pin the refusal paths,
# prompt assembly, and read-only allowlist against a stubbed claude so
# lint/CI catch drift with no API call.
.PHONY: check-ai-review check-ai-review-tools check-review-settings
check-ai-review:
	@scripts/ai-review.fixture.sh
	@grep -qF 'scripts/ai-review.sh <pr>' .claude/commands/start-coding.md || { \
	  echo "ERROR: /start-coding step 6 no longer invokes scripts/ai-review.sh —"; \
	  echo "       the loop and the script must change together (check-gate-query class)"; \
	  exit 1; }
	@if grep -q 'claude -p' .claude/commands/start-coding.md; then \
	  echo "ERROR: /start-coding contains a hand-typed 'claude -p' invocation —"; \
	  echo "       AI review goes through scripts/ai-review.sh only (drift class #30)"; \
	  exit 1; \
	fi
	@echo "check-ai-review: /start-coding still wired to scripts/ai-review.sh (and free of hand-typed invocations)"

# ai-review.yml (CI) must grant exactly the same tool set as scripts/ai-review.sh —
# the #32 class of asymmetry shipped a wide "Bash(gh pr *)" allowlist with no
# write-denials. Extract the quoted tool tokens from each claude invocation block
# (--allowedTools line through the last continuation) and compare as sorted sets,
# so the two can only change together.
.PHONY: check-ai-review-tools
check-ai-review-tools:
	@SH=$$(awk '/^[[:space:]]*--allowedTools/{f=1} f{print} f&&!/\\$$/{exit}' scripts/ai-review.sh | grep -oE '"[A-Za-z]+(\([^)]*\))?"' | sort); \
	 CI=$$(awk '/^[[:space:]]*--allowedTools/{f=1} f{print} f&&!/\\$$/{exit}' .github/workflows/ai-review.yml | grep -oE '"[A-Za-z]+(\([^)]*\))?"' | sort); \
	 if [ "$$SH" != "$$CI" ]; then \
	   echo "ERROR: AI-review tool grants drifted between scripts/ai-review.sh and .github/workflows/ai-review.yml"; \
	   echo "--- scripts/ai-review.sh:"; printf '%s\n' "$$SH"; \
	   echo "--- .github/workflows/ai-review.yml:"; printf '%s\n' "$$CI"; \
	   exit 1; \
	 fi; \
	 echo "check-ai-review-tools: CI tool grants match scripts/ai-review.sh"

# The review session runs against .claude/settings.review.json (--settings) so
# dev-session grants (.claude/settings.json allows `Bash(gh issue *)`) cannot
# widen it. Its deny list must cover every --disallowedTools form in
# scripts/ai-review.sh — deny wins over allow at every settings layer, so the
# settings file is the second line of defense if the CLI list ever drifts.
.PHONY: check-review-settings
check-review-settings:
	@jq -e '.permissions.allow and (.permissions.deny | length > 0)' .claude/settings.review.json >/dev/null 2>&1 || { \
	  echo "ERROR: .claude/settings.review.json missing or malformed"; exit 1; }; \
	DENYF=$$(mktemp); DISF=$$(mktemp); \
	trap 'rm -f "$$DENYF" "$$DISF"' EXIT; \
	jq -r '.permissions.deny[]' .claude/settings.review.json | sort > "$$DENYF"; \
	awk '/^[[:space:]]*--disallowedTools/{f=1} f{print} f&&!/\\$$/{exit}' scripts/ai-review.sh | grep -oE '"[A-Za-z]+(\([^)]*\))?"' | tr -d '"' | sort > "$$DISF"; \
	MISSING=$$(grep -Fxv -f "$$DENYF" "$$DISF" || true); \
	if [ -n "$$MISSING" ]; then \
	  echo "ERROR: .claude/settings.review.json does not deny these tools from scripts/ai-review.sh:"; \
	  printf '%s\n' "$$MISSING"; \
	  exit 1; \
	fi; \
	echo "check-review-settings: review settings deny-list covers scripts/ai-review.sh disallowedTools"

lint:
	@$(MAKE) --no-print-directory check-gate-query
	@$(MAKE) --no-print-directory check-ai-review
	@$(MAKE) --no-print-directory check-ai-review-tools
	@$(MAKE) --no-print-directory check-review-settings
	@if [ -f backend/package.json ]; then cd backend && npm run lint; else echo "backend/ has no package.json yet — skipping lint"; fi
	@if [ -f frontend/package.json ]; then cd frontend && npm run lint; else echo "frontend/ has no package.json yet — skipping lint"; fi

test:
	@if [ -f backend/package.json ]; then cd backend && npm test; else echo "backend/ has no package.json yet — skipping tests"; fi
	@if [ -f frontend/package.json ]; then cd frontend && npm test; else echo "frontend/ has no package.json yet — skipping tests"; fi

test-coverage:
	@if [ -f backend/package.json ]; then cd backend && npm test -- --coverage; else echo "backend/ has no package.json yet — skipping coverage"; fi
	@if [ -f frontend/package.json ]; then cd frontend && npm test -- --coverage; else echo "frontend/ has no package.json yet — skipping coverage"; fi
