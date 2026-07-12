# Testing

The supported development and automated-test runtime is Godot 4.6.3 with vendored GUT 9.6.1. Godot 4.6.3 has been verified on iPhone; Godot 4.7 is deferred because of iOS visual issues.

Import and parse the project:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" --editor --quit
```

Run the complete automated suite:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

Run a focused script by matching its filename:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect progression_definitions -gexit
```

The macOS `get_system_ca_certificates` warning and engine shutdown leak diagnostics may appear without failing the command. Test failures, script parser errors, and crashes are not acceptable.
