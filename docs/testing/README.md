# Testing

The supported development and automated-test runtime is Godot 4.7.1 at `/Applications/Godot 4.7.app/Contents/MacOS/Godot`, with vendored GUT 9.6.1. The prior Godot 4.6.3 iPhone verification does not establish 4.7.1 iOS visual acceptance; repeat that hands-on check before making an iOS claim.

Import and parse the project:

```sh
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" --editor --quit
```

Run the complete automated suite:

```sh
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Run a focused script by matching its filename:

```sh
HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect progression_definitions -gexit
```

The macOS `get_system_ca_certificates` warning and engine shutdown leak diagnostics may appear without failing the command. Test failures, script parser errors, and crashes are not acceptable.

## Responsive acceptance sequence

Before interactive acceptance at `1280x800` or `1920x1080`, run the import and complete suite from any working directory using the exact isolated commands below:

```sh
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars --editor --quit
env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path /Users/adam/github/mars -s addons/gut/gut_cmdln.gd -gexit
```

Both commands must exit zero and every test must pass. Record the exact test and assertion totals with the tested commit. The documented macOS CA warning and engine-shutdown diagnostics remain acceptable; parser errors, crashes, unexpected failures, and nonzero exits do not.

Automated bounds coverage does not establish visual or physical-input acceptance. After it passes:

1. Complete the full controller-only desktop-proxy path at a physical `1280x800` window using the controller, dungeon, and CTB combat manual checklists. Record the OS, controller and connection, resolution, and commit.
2. Complete each checklist's shorter controller-only `1920x1080` regression path.
3. On Steam Deck when hardware is available, verify that an exported build launches borderless at native `1280x800`, then repeat the full handheld path. A desktop `1280x800` window does not replace this hardware pass.

Leave interactive items unchecked until performed. During each path verify viewport and background coverage, text and icon readability, physical control size, unclipped content, focus visibility, deterministic navigation, scroll reveal, cursor and reticle alignment, and animation containment.
