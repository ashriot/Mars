# Vendored Claude Code Skills

Godot domain skills vendored from
[thedivergentai/gd-agentic-skills](https://github.com/thedivergentai/gd-agentic-skills)
(LGPLv3, see `GD-AGENTIC-SKILLS-LICENSE`). Each skill is a `SKILL.md` with
optional `references/` and `scripts/`; Claude Code loads a skill into context
only when a task matches its description, so the set costs nothing at rest.

The selection is curated for Redshift's shape — a 3D battle diorama on the
Mobile renderer over a Control-heavy 2D interface:

- `godot-3d-lighting` — lights, shadows, environment/ambient patterns.
- `godot-3d-materials` — PBR pitfalls (e.g. metallic surfaces under flat ambient).
- `godot-particles` — GPU particles, sub-emitters, VFX pooling for combat.
- `godot-shaders-basics` — hitflash, dissolve, post-FX recipes.
- `godot-camera-systems` — shake, framing, cinematic transitions.
- `godot-ui-theming` — Theme resources, StyleBoxes, variations.
- `godot-platform-mobile` — Mobile-renderer limits and performance budgets.
- `godot-agent-vision` — screenshot-driven visual QA for agent runs.

The upstream `godot-master` orchestrator skill is intentionally excluded: it
bundles the entire library (~15k tokens, hundreds of files) and targets
greenfield architecture rather than an established codebase. Pull additional
individual skills from upstream if a new domain comes up. Skill content is
generic reference material; where it conflicts with `AGENTS.md` or
`docs/`, the repository's own rules win.
