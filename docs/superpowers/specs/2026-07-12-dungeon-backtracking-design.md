# Dungeon Backtracking Restoration Design

## Purpose

Restore the dungeon map's original backtracking behavior after controller-navigation eligibility accidentally made completed nodes unreachable.

## Traversal Rules

During normal `PLAYING` map state, an adjacent node is a valid movement destination when its state is:

- `HIDDEN`: unknown content that becomes revealed as the party enters it.
- `REVEALED`: newly available content that may trigger its interaction after movement.
- `COMPLETED`: previously visited content used for backtracking.

Correction (2026-07-13): adjacent `HIDDEN`, `REVEALED`, and `COMPLETED` nodes are valid movement destinations. The earlier claim that `HIDDEN` nodes were invalid was a controller-navigation regression, not the original traversal rule. The current node remains excluded, and movement remains limited to hex distance 1.

Mouse clicking and keyboard/controller directional selection use the same eligibility rule. A destination must not be valid for one input method and rejected by the other.

## Revisit Behavior

Existing revisit behavior remains authoritative:

- Moving to a node whose `has_been_visited` value is already true applies half of the normal movement alert increase.
- Moving to a completed node does not emit `interaction_requested` again.
- Completed combat, terminal, reward, encounter, and other node content is not replayed by backtracking.
- Backtracking still increments the ordinary move counter and animates/cameras exactly like other movement.

This restoration does not add pathfinding or multi-node automatic travel. Players retrace the map one adjacent node at a time.

## Targeting Mode

Targeting/scanning remains separate from normal traversal. Under free scanning, every generated hex is an eligible scan center, including hidden, current, and completed hexes.

## Testing

Automated regressions verify:

- Controller/keyboard directional navigation can preview and confirm an adjacent completed node.
- Mouse clicking can move to the same adjacent completed node.
- Hidden, revealed, and completed adjacent nodes are valid; current and non-adjacent nodes remain invalid.
- Moving backward to a visited node adds exactly half the configured movement alert cost.
- Completed-node backtracking emits no interaction request.
- Revealed-node forward movement continues to emit its interaction normally.
- Controller and mouse eligibility agree for revealed, completed, and hidden nodes.

Focused dungeon navigation/restore tests and the full GUT suite must pass. The unrelated local `project.godot` modification remains outside this work.
