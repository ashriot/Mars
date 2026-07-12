# Vendored GUT

- Source: https://github.com/bitwes/Gut
- Tag: `v9.6.1`
- Upstream commit: `c80954f47bed74a0a2c471d472c0389f98e0a8f6`
- Runtime version: GUT 9.6.1
- Retrieved from: `https://github.com/bitwes/Gut/archive/refs/tags/v9.6.1.zip`
- Local modifications: trailing whitespace and extra blank lines at end of text files were normalized to satisfy repository diff hygiene.

The project and automated test baseline is Godot 4.6.3. This version has been verified on iPhone; Godot 4.7 is deferred because of iOS visual issues.

After importing the project once, run the suite with:

```sh
HOME=/tmp/mars-godot-home /Applications/Godot.app/Contents/MacOS/Godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
```

On macOS this command may emit a nonfatal `get_system_ca_certificates` warning while the tests still run and report their results normally.
