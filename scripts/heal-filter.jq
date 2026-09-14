# story-done heal-sweep filter — selects board items whose story issue is
# CLOSED+COMPLETED, story-labeled, from this repo, and not yet Done.
# Pinned by scripts/heal-filter.fixture.json via the conventions CI job:
# a regression here silently no-ops the sweep (the round-4 🔴 class).
.data.node.items.nodes[]?
| select((.content.state? // "") == "CLOSED")
| select((.content.stateReason? // "") == "COMPLETED")
| select((.content.repository.nameWithOwner? // "") == $repo)
| select(any(.content.labels.nodes[]?.name; . == "story"))
| select(([.fieldValues.nodes[]? | select(.field.name == $f) | .name] | first) != $done)
| "\(.id)\t\(.content.number)"
