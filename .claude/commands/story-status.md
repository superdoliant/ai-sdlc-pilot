---
description: Read-only check of a story's board status before starting work — the inspection /start-coding gates on
argument-hint: <issue number>
---
Check, report, and change nothing:

1. Board status — run (coordinates derived, so the command ports to other repos untouched):
   REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner); OWNER=${REPO%/*}; NAME=${REPO#*/}
   gh api graphql -f query='query($o: String!, $r: String!, $n: Int!){ repository(owner: $o, name: $r){ issue(number: $n){ state title projectItems(first: 10){ nodes{ project{title} fieldValues(first: 10){ nodes{ ... on ProjectV2ItemFieldSingleSelectValue{ name field{ ... on ProjectV2SingleSelectField{ name } } } } } } } } } }' -f o=$OWNER -f r=$NAME -F n=$ARGUMENTS
   Report the issue state and the card's Status field value (or "not on the board").

2. Test plan — check whether docs/test-plans/issue-$ARGUMENTS-test-plan.md exists.
   Informational only: the plan is reviewed as part of card review, not via a comment.

Gate rule (CLAUDE.md): implementation starts only via `/start-coding <n>`, which refuses
anything that is not Ready or In progress (Backlog, In review, Done, or unboarded). If
the card is at **Backlog** or not on the board, report that implementation must not
start and the card needs human review and Ready promotion — then wait for the user's
instruction.
