---
description: Draft a user story from a brief and create the GitHub issue
argument-hint: <feature brief in quotes, or an existing raw issue number to expand>
---
You are drafting a user story for this repository's team.

Input: $ARGUMENTS

Steps:
1. If the input is an issue number, run `gh issue view <n> --json title,body,comments`
   and treat its body as the brief. Otherwise the input text is the brief.
2. Read CLAUDE.md for project context and the required story template.
3. Check `gh issue list --state all --limit 50` for duplicates; mention related issues if found.
4. Draft the story following the story template in CLAUDE.md exactly
   (Context / User story / Acceptance criteria in Given-When-Then / Edge cases ≥3 /
   Out of scope / Open questions / Testability notes).
   Ground everything in this repo's actual domain — no generic filler.
5. Show me the full draft and ask for confirmation before creating anything.
6. After I confirm, create it:
   `gh issue create --title "<short imperative title>" --body-file /tmp/story.md --label story --label ai-draft`
7. Give me the issue URL and remind me: a human must review it before it becomes Ready.

Never: transition issue state yourself, assign people, remove the ai-draft label, or close issues.
