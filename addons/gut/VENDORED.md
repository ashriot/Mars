# Vendored GUT

- Source: https://github.com/bitwes/Gut
- Branch: `godot_4_7`
- Upstream commit: `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605`
- Runtime version: GUT 9.7.1
- Retrieved from: `https://github.com/bitwes/Gut/archive/refs/heads/godot_4_7.zip`
- Local modifications: trailing whitespace and extra blank lines at end of text files were normalized to satisfy repository diff hygiene.

The production project metadata remains Godot 4.6. The automated test harness currently requires the installed Godot 4.7 binary and the vendored GUT 9.7.1 runtime.

After importing the project once, run the suite with:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot -d -s --headless --path "$PWD" addons/gut/gut_cmdln.gd -gexit
```

On macOS this command may emit a nonfatal `get_system_ca_certificates` warning while the tests still run and report their results normally.
