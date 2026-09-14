---
description: Start work on a story — mechanical Ready gate, sync main, create and push the story branch, implement, then converge the AI review before handoff
argument-hint: <issue number>
---
The single entry point for implementation work. Run the steps in order — the first
check that fails stops the whole command. Never skip step 1-2 "just to get started".

1. Read the issue: `gh issue view $ARGUMENTS --json state,title,body`.
   Missing issue → STOP. Closed issue → STOP and say so: a story's lifecycle is terminal
   at Done, follow-up work gets its own issue (CLAUDE.md).

2. Board gate — check the card's Status (the `/story-status` query, coordinates derived
   so the command ports to other repos untouched):
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner); OWNER=${REPO%/*}; NAME=${REPO#*/}
   gh api graphql -f query='query($o: String!, $r: String!, $n: Int!){ repository(owner: $o, name: $r){ issue(number: $n){ state title projectItems(first: 10){ nodes{ project{title} fieldValues(first: 10){ nodes{ ... on ProjectV2ItemFieldSingleSelectValue{ name field{ ... on ProjectV2SingleSelectField{ name } } } } } } } } } }' -f o=$OWNER -f r=$NAME -F n=$ARGUMENTS
   Read the value of the field named `Status` from the item on this repo's board — if
   items come back from more than one project, report the ambiguity instead of
   guessing. No `Status` value or no card at all = not on the board. Then:
   - **Ready** → continue with step 3
   - **In progress** → resume mode: first apply the same clean-tree rule as step 3
     (`git status --porcelain` must print nothing — dirty → STOP and show it). Locate
     the branch where it is authoritative — the remote:
     `git ls-remote --heads origin "story/$ARGUMENTS-*"`
     (local listings miss never-fetched branches, and remote-tracking names carry an
     `origin/` prefix that `story/$ARGUMENTS-*` patterns don't match). Branch name =
     the ref with `refs/heads/` stripped. If more than one ref matches, STOP and list
     them — the user picks which branch is the story's (multi-branch stories exist in
     this repo's own history; never pick arbitrarily). If exactly one: `git switch
     <branch>` when it exists locally, else `git switch -c <branch> --track
     origin/<branch>`; if git reports it is already checked out in another worktree,
     STOP and pass that worktree path to the user (never switch with `--force`). After
     switching, `git pull --ff-only` when the branch tracks a remote — if the pull
     refuses (diverged local branch), STOP with its exact output. Then skip to step 5.
     If the remote has no such branch but a local-only one exists
     (`git branch --list 'story/$ARGUMENTS-*'`), switch to it and skip to step 5;
     only otherwise fall through to steps 3-4 and create it fresh.
   - **Backlog** → STOP: "Card #$ARGUMENTS is at Backlog — review it and promote it to
     Ready first." Create no branch, write no code, wait for the user
   - **In review** → STOP starting new work — the story's PR already exists. To address
     review feedback, apply the same clean-tree rule as resume mode, then locate the
     existing `story/$ARGUMENTS-*` branch with the same `git ls-remote` recipe as
     above, switch to it, and push (the open PR picks it up; the card stays in
     review), then resume the loop at step 6 on that same PR — its number comes
     from `gh pr list --head <branch> --json number` (exactly one open PR is
     expected; anything else, STOP and ask), continuing round numbering from
     the PR body's review-loop log (a resumed loop opens at `round N+1: fresh
     review after resume`, never round 1 again; no log in the body → STOP and
     ask); only unrelated follow-up gets a new issue
   - **not on the board / Done** → STOP with guidance: follow-up work needs a new
     issue; an unboarded story needs boarding before it can be worked on

3. Sync: first require a clean tree — `git status --porcelain` must print nothing.
   If it prints anything (modified, staged, or untracked files — including
   non-conflicting ones, which `git checkout` would silently carry along), STOP and show
   the output: the user's working tree is not yours to touch, and carried-along files
   end up swept into the PR. Then `git checkout main && git pull --ff-only`; if git
   still refuses (e.g. diverged history), STOP with its exact output. Never stash,
   force, reset, or clean on the user's behalf.

4. Branch: `git checkout -b story/$ARGUMENTS-<short-slug>` (match the story to a
   1-3 word slug), then `git push -u origin story/$ARGUMENTS-<short-slug>`.
   This push moves the card to In progress (story-status.yml) — that is expected and
   is the lifecycle connecting, not a side effect to suppress.

5. Implement per CLAUDE.md: acceptance criteria are the contract; work from the
   reviewed test plan at docs/test-plans/issue-$ARGUMENTS-test-plan.md — if it is
   missing, draft one with `/test-plan $ARGUMENTS` and say so in the PR (a reviewed
   artifact must never be silently regenerated); generate tests with `/gen-tests`
   where applicable; `make lint` and `make test` must pass before each push. End by
   opening the PR to `main` whose body contains a closing keyword for the story
   ("Closes #$ARGUMENTS") — story-review.yml then moves the card to In review.

6. AI-review convergence loop — mandatory, immediately after the PR exists
   (opened in step 5, or an already-open PR this run just updated). The loop is
   procedural, never ad-hoc: every round is `scripts/ai-review.sh`, the identical
   scripted invocation, differing between rounds only in the quoted round-context
   arg (never hand-type a variant — the #30 gate-query brace was hand-copy drift).
   1. A fresh loop opens with `scripts/ai-review.sh <pr> "round 1: fresh review"`;
      a resumed loop opens at round N+1 per the In review bullet above. Run it
      and read the output. A clean round 1 (no 🔴/🟡, verdict "no blocking
      concerns", `gh pr checks` green) is already converged — skip straight to
      handoff below, unless the story's own validation plan demands a witnessed
      iteration. After every round, clean or not, append its number,
      invocation, and outcome to a **Review-loop log** section in the PR body —
      the persisted trail the In-review resume path continues. The per-push CI
      backstop (`ai-review.yml`) reviews every mid-loop push; treat its
      findings as loop findings — fold their fixes into the next round's entry
      or log them as their own entries marked `backstop` — and before handoff
      the log must cover every fix commit on the PR.
   2. Fix every 🔴/🟡 finding (💬 findings are folded into nearby fixes or
      explicitly dismissed with a reason in the PR body), commit, push.
   3. Re-run with round context: `scripts/ai-review.sh <pr> "round N: verify
      fixes for <one-line list of what round N-1 flagged and you changed> and
      re-review fresh"` — then confirm `gh pr checks` shows the required checks
      green.
   4. Converged = verdict "no blocking concerns" + no unresolved 🔴/🟡 findings +
      required checks green. Anything less and the loop continues.
   5. Budget: after 10 rounds without convergence, STOP and report honestly what
      remains — never rubber-stamp a round to exit the loop.
   6. Hand the PR to the user as ready for human merge.

Merging is never part of this command. The merge click belongs to a human, always.
