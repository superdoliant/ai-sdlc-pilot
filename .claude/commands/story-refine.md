---
description: Check a story against the Definition of Ready before refinement
argument-hint: <issue number>
---
Run `gh issue view $ARGUMENTS --json title,body,labels,comments` and grade the story
against the story template in CLAUDE.md, treating each section of the template as a
Definition-of-Ready item (context present, testable Given/When/Then acceptance criteria,
edge cases listed, scope bounded, open questions surfaced, testability notes present).

Output a markdown table: item | pass/fail | what's missing | concrete suggested wording.
If everything passes, say "Ready to promote". Do not edit the issue yourself.
