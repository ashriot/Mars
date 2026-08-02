#!/usr/bin/env bash
set -euo pipefail

readonly DEFAULT_DEST_ROOT="assets/graphics/models/quaternius_local"
readonly ESSENTIALS_FILES=(
  "License_Standard.txt"
  "glTF/Enemy_EyeDrone.gltf"
  "glTF/Enemy_EyeDrone.bin"
  "glTF/T_Enemies_BaseColor_png.png"
  "glTF/T_Enemies_Normal.png"
  "glTF/T_Enemies_ORM.png"
)
readonly MEGAKIT_MODELS=(
  "License_Standard.txt"
  "glTF/Walls/WallAstra_Straight_Flat.gltf"
  "glTF/Walls/WallAstra_Straight_Flat.bin"
  "glTF/Walls/TopAstra_Straight.gltf"
  "glTF/Walls/TopAstra_Straight.bin"
  "glTF/Walls/BottomMetal_Straight.gltf"
  "glTF/Walls/BottomMetal_Straight.bin"
  "glTF/Platforms/Platform_Metal.gltf"
  "glTF/Platforms/Platform_Metal.bin"
  "glTF/Columns/Column_Astra.gltf"
  "glTF/Columns/Column_Astra.bin"
  "glTF/Props/Prop_Light_Wide.gltf"
  "glTF/Props/Prop_Light_Wide.bin"
  "glTF/Props/Prop_Vent_Wide.gltf"
  "glTF/Props/Prop_Vent_Wide.bin"
  "glTF/Props/Prop_Cable_1.gltf"
  "glTF/Props/Prop_Cable_1.bin"
)
readonly MEGAKIT_TEXTURES=(
  "Textures/T_Trim_01_BaseColor_Red.png"
  "Textures/T_Trim_01_Normal.png"
  "Textures/T_Trim_01_ORM.png"
  "Textures/T_Trim_02_BaseColor_Red.png"
  "Textures/T_Trim_02_Normal.png"
  "Textures/T_Trim_02_ORM.png"
  "Textures/T_Trim_03_BaseColor.png"
  "Textures/T_Trim_03_Cables.png"
  "Textures/T_Trim_03_Normal.png"
  "Textures/T_Trim_03_ORM.png"
)

readonly REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

print_manifest() {
  printf '%s\n' "$@"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

destination_is_in_worktree() {
  local destination=$1
  local worktree_root

  if ! worktree_root=$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null); then
    return 1
  fi

  case "$destination" in
    "$worktree_root"|"$worktree_root"/*)
      return 0
      ;;
  esac

  return 1
}

validate_source_files() {
  local source_root=$1
  local relative_path
  shift

  for relative_path in "$@"; do
    [[ -f "$source_root/$relative_path" ]] || fail "Required source file is missing: $source_root/$relative_path"
  done
}

copy_files_flattened() {
  local source_root=$1
  local destination=$2
  shift 2
  local relative_path

  for relative_path in "$@"; do
    cp "$source_root/$relative_path" "$destination/${relative_path##*/}"
  done
}

if [[ ${1:-} == "--print-essentials-manifest" && $# -eq 1 ]]; then
  print_manifest "${ESSENTIALS_FILES[@]}"
  exit 0
fi

if [[ ${1:-} == "--print-megakit-manifest" && $# -eq 1 ]]; then
  print_manifest "${MEGAKIT_MODELS[@]}"
  print_manifest "${MEGAKIT_TEXTURES[@]}"
  exit 0
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  fail "Usage: $0 ESSENTIALS_ROOT MEGAKIT_ROOT [DEST_ROOT]"
fi

ESSENTIALS_ROOT=$1
MEGAKIT_ROOT=$2
DEST_ROOT=${3:-$DEFAULT_DEST_ROOT}

cd "$REPO_ROOT"

[[ -d "$ESSENTIALS_ROOT" ]] || fail "Essentials root is not a directory: $ESSENTIALS_ROOT"
[[ -d "$MEGAKIT_ROOT" ]] || fail "MegaKit root is not a directory: $MEGAKIT_ROOT"
[[ -n "$DEST_ROOT" ]] || fail "Destination root must not be empty"
[[ ! -e "$DEST_ROOT" || -d "$DEST_ROOT" ]] || fail "Destination root is not a directory: $DEST_ROOT"

validate_source_files "$ESSENTIALS_ROOT" "${ESSENTIALS_FILES[@]}"
validate_source_files "$MEGAKIT_ROOT" "${MEGAKIT_MODELS[@]}"
validate_source_files "$MEGAKIT_ROOT" "${MEGAKIT_TEXTURES[@]}"

if [[ "$DEST_ROOT" != /* ]]; then
  DEST_ROOT="$REPO_ROOT/$DEST_ROOT"
fi

if destination_is_in_worktree "$DEST_ROOT"; then
  git -C "$REPO_ROOT" check-ignore -q -- "$DEST_ROOT/" || fail "Destination root must be ignored by Git: $DEST_ROOT"
fi

mkdir -p "$DEST_ROOT/enemies/eye_drone" "$DEST_ROOT/environment/industrial"
copy_files_flattened "$ESSENTIALS_ROOT" "$DEST_ROOT/enemies/eye_drone" "${ESSENTIALS_FILES[@]:1}"
copy_files_flattened "$MEGAKIT_ROOT" "$DEST_ROOT/environment/industrial" "${MEGAKIT_MODELS[@]:1}"
copy_files_flattened "$MEGAKIT_ROOT" "$DEST_ROOT/environment/industrial" "${MEGAKIT_TEXTURES[@]}"
cp "$ESSENTIALS_ROOT/License_Standard.txt" "$DEST_ROOT/LICENSE_SCI_FI_ESSENTIALS.txt"
cp "$MEGAKIT_ROOT/License_Standard.txt" "$DEST_ROOT/LICENSE_MODULAR_SCI_FI_MEGAKIT.txt"

if destination_is_in_worktree "$DEST_ROOT"; then
  while IFS= read -r installed_file; do
    git -C "$REPO_ROOT" check-ignore -q -- "$installed_file" || fail "Installed file is not ignored by Git: $installed_file"
  done < <(find "$DEST_ROOT" -type f -print)

  if [[ -n $(git -C "$REPO_ROOT" ls-files -- "$DEST_ROOT") ]]; then
    fail "Git tracks files under the local vendor destination: $DEST_ROOT"
  fi
fi

installed_file_count=$(find "$DEST_ROOT" -type f | wc -l | tr -d ' ')
printf 'Installed %s files in %s\n' "$installed_file_count" "$DEST_ROOT"
