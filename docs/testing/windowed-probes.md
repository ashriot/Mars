# Windowed probes: answering how-does-it-feel questions

**`--headless` uses the dummy rendering driver — it renders nothing. There are
no pixels to capture, no matter how you try.** Headless proves logic; windowed
proves it reads right. Anything about colour, size, layout, legibility,
lighting, or timing needs a windowed probe. The
[mobile battle lighting spec](../superpowers/specs/2026-08-23-mobile-battle-lighting-and-hidpi-design.md)
makes windowed framebuffer probes the authority for visual acceptance.

A probe is a throwaway `SceneTree` script that boots the real scene, stages a
situation, and screenshots itself:

```gdscript
extends SceneTree

func _init() -> void:
	var lab: Node = load("res://src/dev/endgame_battle_lab.tscn").instantiate()
	root.add_child(lab)
	for i in 90:
		await process_frame          # let it render and settle
	# ...stage here: apply a condition, trigger an ability, force a guard break...
	for i in 20:
		await process_frame
	root.get_texture().get_image().save_png("/tmp/probe_shot.png")
	quit()
```

Run it **without** `--headless` — a window opens briefly and real frames
render. Keep the isolated `HOME` from [testing/README.md](README.md) so the
probe boots against clean state:

```sh
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --path "$PWD" --resolution 1920x1080 --script res://_probe.gd
```

`get_texture().get_image()` reads the viewport framebuffer directly: no OS
screen capture, no permissions prompt, works with the window behind others.

An equivalent form is a temporary scene whose root script counts frames in
`_process` and captures via `get_viewport().get_texture().get_image()`; use
whichever stages the situation more easily. On a machine with no display, a
virtual display (e.g. `xvfb-run` with a GL driver) renders real frames where
`--headless` cannot.

## Gotchas that cost real time

- **The probe must live inside the project** — `res://` can't see outside it.
  Create it at the repo root (an underscore prefix like `_probe.gd` keeps it
  obviously disposable), run it, then delete it *and its `.uid` sidecar*.
  Never commit a probe.
- **Await frames before capturing.** Capturing in the same frame as setup gives
  an empty or stale image. Projectiles and animations also need frames to
  travel — capture at several frame counts and pick.
- **Type-annotate `load(...).instantiate()` results** (`var lab: Node = ...`).
  Bare `:=` fails to infer and the probe won't parse.
- **Print state alongside pixels.** A line like `step=2 window=5.00 focus=4` is
  often more diagnostic than the screenshot; the image confirms what the log
  already told you.
- **Enlarge before reading.** Crop to the region of interest and scale up — an
  action-bar slot at native size in a 1920×1080 frame is unreadable.
- **Isolate what you're judging.** Two projectiles in flight at once are
  indistinguishable in a still; fire one, capture, then the other.
- **Watch persistence.** This project saves real run state through
  `SaveSystem`/`RunManager`. The isolated `HOME` above is what keeps a probe
  from eating a real save — never run a probe against your ordinary `HOME`.
- **Probe the real ancestry, not just the isolated scene.** The battle scene
  lit correctly alone but rendered black inside `GameManager` (a second
  `WorldEnvironment` won); only a probe of the full parent chain exposed it.
  Stage probes through the same scene ownership players get.

Real issues probes caught here that reviews and headless tests missed: the
arena rendering near-black and the projected enemy HUDs vanishing only under
`GameManager` ancestry, and material values calibrated against that broken
pipeline reading too hot once ambient light actually applied.
