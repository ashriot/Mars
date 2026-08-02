#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mars-quaternius-test.XXXXXX")
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

ESSENTIALS_ROOT="$FIXTURE_ROOT/essentials"
MEGAKIT_ROOT="$FIXTURE_ROOT/megakit"
DEST_ROOT="$FIXTURE_ROOT/output"

mkdir -p "$ESSENTIALS_ROOT/glTF" "$MEGAKIT_ROOT/glTF/Walls" \
  "$MEGAKIT_ROOT/glTF/Platforms" "$MEGAKIT_ROOT/glTF/Columns" \
  "$MEGAKIT_ROOT/glTF/Props" "$MEGAKIT_ROOT/Textures"

while IFS= read -r relative_path; do
  mkdir -p "$(dirname "$ESSENTIALS_ROOT/$relative_path")"
  printf '%s\n' "$relative_path" > "$ESSENTIALS_ROOT/$relative_path"
done < <("$REPO_ROOT/tools/setup_quaternius_local_assets.sh" --print-essentials-manifest)

while IFS= read -r relative_path; do
  mkdir -p "$(dirname "$MEGAKIT_ROOT/$relative_path")"
  printf '%s\n' "$relative_path" > "$MEGAKIT_ROOT/$relative_path"
done < <("$REPO_ROOT/tools/setup_quaternius_local_assets.sh" --print-megakit-manifest)

"$REPO_ROOT/tools/setup_quaternius_local_assets.sh" \
  "$ESSENTIALS_ROOT" "$MEGAKIT_ROOT" "$DEST_ROOT"

test "$(find "$DEST_ROOT" -type f | wc -l | tr -d ' ')" = "33"
test -f "$DEST_ROOT/enemies/eye_drone/Enemy_EyeDrone.gltf"
test -f "$DEST_ROOT/environment/industrial/Prop_Cable_1.gltf"
test -f "$DEST_ROOT/LICENSE_SCI_FI_ESSENTIALS.txt"
test -f "$DEST_ROOT/LICENSE_MODULAR_SCI_FI_MEGAKIT.txt"
test ! -e "$DEST_ROOT/Preview_1.png"

rm "$MEGAKIT_ROOT/Textures/T_Trim_03_ORM.png"
if "$REPO_ROOT/tools/setup_quaternius_local_assets.sh" \
  "$ESSENTIALS_ROOT" "$MEGAKIT_ROOT" "$FIXTURE_ROOT/missing-output"; then
  exit 1
fi
test ! -e "$FIXTURE_ROOT/missing-output"
