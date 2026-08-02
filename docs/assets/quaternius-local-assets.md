# Curated local Quaternius assets

The first local 3D battle slice uses a deliberately small, local-only subset of
[Quaternius](https://quaternius.com/) CC0 1.0 assets. The vendor files are not
part of this repository: `assets/graphics/models/quaternius_local/` is ignored
and Git LFS is intentionally not used, because LFS would still upload the
assets to GitHub.

## Source kits and installation

Download the Standard editions of these Quaternius kits, then run this command
from the repository root:

```bash
tools/setup_quaternius_local_assets.sh \
  '/Users/adam/Downloads/Sci-Fi Essentials Kit[Standard]' \
  '/Users/adam/Downloads/Modular SciFi MegaKit[Standard]'
```

The installer validates every required source file before it creates the local
destination. It refuses a destination inside this worktree unless Git ignores
it, then verifies all installed files remain ignored and untracked.

## Curated source manifest

From `Sci-Fi Essentials Kit[Standard]`, install these paths into
`assets/graphics/models/quaternius_local/enemies/eye_drone/` (flattened):

```text
glTF/Enemy_EyeDrone.gltf
glTF/Enemy_EyeDrone.bin
glTF/T_Enemies_BaseColor_png.png
glTF/T_Enemies_Normal.png
glTF/T_Enemies_ORM.png
```

Its `License_Standard.txt` is copied to the local root as
`LICENSE_SCI_FI_ESSENTIALS.txt`.

From `Modular SciFi MegaKit[Standard]`, install these model pairs into
`assets/graphics/models/quaternius_local/environment/industrial/` (flattened):

```text
glTF/Walls/WallAstra_Straight_Flat.gltf
glTF/Walls/WallAstra_Straight_Flat.bin
glTF/Walls/TopAstra_Straight.gltf
glTF/Walls/TopAstra_Straight.bin
glTF/Walls/BottomMetal_Straight.gltf
glTF/Walls/BottomMetal_Straight.bin
glTF/Platforms/Platform_Metal.gltf
glTF/Platforms/Platform_Metal.bin
glTF/Columns/Column_Astra.gltf
glTF/Columns/Column_Astra.bin
glTF/Props/Prop_Light_Wide.gltf
glTF/Props/Prop_Light_Wide.bin
glTF/Props/Prop_Vent_Wide.gltf
glTF/Props/Prop_Vent_Wide.bin
glTF/Props/Prop_Cable_1.gltf
glTF/Props/Prop_Cable_1.bin
```

Install these MegaKit textures into the same industrial directory:

```text
Textures/T_Trim_01_BaseColor_Red.png
Textures/T_Trim_01_Normal.png
Textures/T_Trim_01_ORM.png
Textures/T_Trim_02_BaseColor_Red.png
Textures/T_Trim_02_Normal.png
Textures/T_Trim_02_ORM.png
Textures/T_Trim_03_BaseColor.png
Textures/T_Trim_03_Cables.png
Textures/T_Trim_03_Normal.png
Textures/T_Trim_03_ORM.png
```

Its `License_Standard.txt` is copied to the local root as
`LICENSE_MODULAR_SCI_FI_MEGAKIT.txt`.

The local destination therefore has this structure:

```text
quaternius_local/
  LICENSE_SCI_FI_ESSENTIALS.txt
  LICENSE_MODULAR_SCI_FI_MEGAKIT.txt
  enemies/eye_drone/
    Enemy_EyeDrone.gltf
    Enemy_EyeDrone.bin
    T_Enemies_BaseColor_png.png
    T_Enemies_Normal.png
    T_Enemies_ORM.png
  environment/industrial/
    eight selected .gltf/.bin module pairs
    ten selected T_Trim_* textures
```

## Verification and recovery

Run the isolated installer check without the downloaded kits:

```bash
bash test/tools/test_setup_quaternius_local_assets.sh
```

After installing, confirm Git still excludes the vendor root:

```bash
git check-ignore -v assets/graphics/models/quaternius_local/enemies/eye_drone/Enemy_EyeDrone.gltf
git ls-files assets/graphics/models/quaternius_local
git diff --cached --name-only | rg '^assets/graphics/models/quaternius_local/'
```

If the local assets are missing, download the two source kits again and rerun
the setup command. If a local installation needs to be replaced, remove only
`assets/graphics/models/quaternius_local/` and rerun the installer; no tracked
repository file needs to change.
