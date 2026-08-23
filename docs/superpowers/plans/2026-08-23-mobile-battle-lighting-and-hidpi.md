# Mobile Battle Lighting and HiDPI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the industrial battle arena readable and dimensional on the Forward Mobile renderer, while preserving a 1280×800 minimum composition and deliberate 1920×1080/4K UI scaling.

**Architecture:** Keep display scaling in the existing `DisplayProfileService`/`Main` policy: 1280×800 uses a uniformly scaled 1920×1200 logical canvas with a centered 1920×1080 safe composition; 1920×1080 and 3840×2160 use the 1920×1080 reference composition, with 4K rendered at 2× output scale. Replace the room's broad, flat Mobile fake-GI rig with a single shadowed key, contained non-shadowed fill, subtle diffuse bounce, and a restrained rear practical accent. The scenes remain data-only; GUT tests define the scaling and light-budget contracts.

**Tech Stack:** Godot 4.7.1 Forward Mobile, GDScript, GUT, windowed framebuffer probes.

**Spec:** [Mobile Battle Lighting and HiDPI Design](../specs/2026-08-23-mobile-battle-lighting-and-hidpi-design.md)

## Global Constraints

- Use `/Applications/Godot 4.7.app/Contents/MacOS/Godot` and the isolated `HOME` required by `docs/testing/README.md` for every automated run.
- Retain Forward Mobile compatibility: no GI/VoxelGI/SDFGI, lightmaps, reflection probes, volumetric fog, or screen-space-only lighting requirements.
- The room may have exactly one shadow-casting light. Local fill, bounce, and accent lights must not cast shadows.
- Do not change the existing display-profile production implementation unless the characterization test exposes a real regression. The desired 4K behavior already exists; this work locks it down.
- Use a windowed probe for visual acceptance. `--headless` can validate logic only and cannot validate lighting, layout, or output scale.
- Preserve unrelated dirty work. Before each commit, stage only the paths named for that task.
- The pre-existing hero-row/seam repair is intentionally committed first, separately from the lighting work; it is already verified and should not become an incidental hunk in the lighting commit.

---

## Task 1: Land the accepted battle-composition and shell-seam repair

**Files:**

- Modify: `src/battle/battle_scene.tscn`
- Modify: `src/battle/presentation/industrial_room_3d.tscn`
- Modify: `test/integration/test_battle_responsive_layout.gd`
- Modify: `test/integration/test_battle_world_3d.gd`

- [ ] **1.1 Re-audit the existing patch before staging it.**

  Confirm the only intended changes are: the hero row is moved from `offset_top = -506.0`/`offset_bottom = -326.0` to `-376.0`/`-196.0`; the floor rises from `-0.3` to `-0.1`; the ceiling backer lowers from `5.45` to `4.95`; and the associated responsive-layout/world-AABB tests are present. Do not fold lighting value changes into this commit.

  Run:

  ```bash
  git diff --check -- src/battle/battle_scene.tscn src/battle/presentation/industrial_room_3d.tscn test/integration/test_battle_responsive_layout.gd test/integration/test_battle_world_3d.gd
  ```

- [ ] **1.2 Re-run the focused regression tests.**

  ```bash
  env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_responsive_layout -gexit
  env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gexit
  ```

  Expected: both commands exit zero. The world test must prove both the transformed floor/wall bounds and ceiling/wall bounds overlap rather than merely touch.

- [ ] **1.3 Commit the repair independently.**

  ```bash
  git add src/battle/battle_scene.tscn src/battle/presentation/industrial_room_3d.tscn test/integration/test_battle_responsive_layout.gd test/integration/test_battle_world_3d.gd
  git commit -m "fix: clear battle stage and seal room shell"
  ```

  Verify `git show --stat --oneline HEAD` lists only those four files.

## Task 2: Characterize the 4K reference-composition policy

**Files:**

- Modify: `test/unit/test_display_profile_service.gd`

- [ ] **2.1 Add the 4K display-profile regression test.**

  Add this test after the existing expanded-deck canvas test:

  ```gdscript
  func test_4k_output_keeps_the_reference_composition_at_two_x_scale() -> void:
      var output := Vector2i(3840, 2160)

      assert_almost_eq(
          DisplayProfileServiceScript.output_scale_for(output),
          2.0,
          0.001,
          "4K should render the reference canvas at 2x",
      )
      assert_eq(
          DisplayProfileServiceScript.expanded_logical_size_for(output),
          Vector2(1920, 1080),
          "4K must retain the authored 1920x1080 logical composition",
      )
      assert_eq(
          DisplayProfileServiceScript.safe_rect_for(Vector2(1920, 1080)),
          Rect2(Vector2.ZERO, DisplayProfileServiceScript.REFERENCE_SIZE),
          "the reference canvas should need no letterboxing",
      )
  ```

  This is a characterization test: it should pass immediately because the current implementation already has the intended policy. Do not add a 4K-specific layout branch.

- [ ] **2.2 Run the focused display tests.**

  ```bash
  env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect display_profile_service -gexit
  env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect main_display_layout -gexit
  ```

  Expected: both commands exit zero. The tests together establish 1280×800 downscaling, 1920×1080 reference composition, and 4K 2× raster scale.

- [ ] **2.3 Commit the contract.**

  ```bash
  git add test/unit/test_display_profile_service.gd
  git commit -m "test: lock battle UI 4k scaling policy"
  ```

## Task 3: Replace the flat Mobile room rig with a directional lighting hierarchy

**Files:**

- Modify: `src/battle/presentation/battle_world_3d.tscn`
- Modify: `src/battle/presentation/industrial_room_3d.tscn`
- Modify: `test/integration/test_battle_world_3d.gd`

- [ ] **3.1 Write the scene-lighting contract first.**

  Replace the old `test_room_uses_mobile_fake_gi_lighting` expectations with a contract for the new hierarchy. Assert exact names/types and the following authored values:

  ```gdscript
  assert_eq(environment.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
  assert_eq(environment.ambient_light_color, Color(0.22, 0.28, 0.40))
  assert_almost_eq(environment.ambient_light_energy, 0.45, 0.001)

  var key := room.get_node("RoomKeyLight") as DirectionalLight3D
  assert_eq(key.rotation_degrees, Vector3(-52.0, -34.0, 0.0))
  assert_eq(key.light_color, Color(0.76, 0.86, 1.0))
  assert_almost_eq(key.light_energy, 1.35, 0.001)
  assert_true(key.shadow_enabled)

  var fill := room.get_node("RoomFillLight") as OmniLight3D
  assert_eq(fill.position, Vector3(-2.5, 2.6, 5.0))
  assert_eq(fill.light_color, Color(0.34, 0.52, 0.85))
  assert_almost_eq(fill.light_energy, 1.25, 0.001)
  assert_almost_eq(fill.omni_range, 9.0, 0.001)
  assert_false(fill.shadow_enabled)

  var accent := room.get_node("RoomAccentLight") as OmniLight3D
  assert_eq(accent.position, Vector3(0.0, 3.6, -5.5))
  assert_eq(accent.light_color, Color(0.92, 0.28, 0.18))
  assert_almost_eq(accent.light_energy, 1.10, 0.001)
  assert_almost_eq(accent.omni_range, 7.0, 0.001)
  assert_false(accent.shadow_enabled)

  var bounce := room.get_node("RoomBounceLight") as DirectionalLight3D
  assert_almost_eq(bounce.light_energy, 0.20, 0.001)
  assert_almost_eq(bounce.light_specular, 0.0, 0.001)
  assert_false(bounce.shadow_enabled)
  ```

  Also gather the four room lights and assert that exactly one has `shadow_enabled == true`. Preserve the existing assertion that `RoomFrontLight` does not exist. Run the focused world test; it must fail before the scene values change.

- [ ] **3.2 Author the new rig in the two scene resources.**

  In `battle_world_3d.tscn`, set the `Environment` ambient source to color with `ambient_light_color = Color(0.22, 0.28, 0.40, 1)` and `ambient_light_energy = 0.45`. Retain ACES tonemapping and `tonemap_exposure = 1.0`; do not compensate with broad exposure changes.

  In `industrial_room_3d.tscn`, set the existing key, fill, and bounce nodes to the contract values in step 3.1. Add a non-shadowed `OmniLight3D` named `RoomAccentLight` at `(0, 3.6, -5.5)` using the contracted warm value. Keep the existing emissive practical meshes; they provide visual storytelling without adding another shadow cost.

  The resulting hierarchy is intentional:

  ```text
  RoomKeyLight      directional, cool, shadowed — shape and depth
  RoomFillLight     local, cool, no shadows     — readable foreground
  RoomBounceLight   directional, diffuse only   — restrained fake bounce
  RoomAccentLight   local, warm, no shadows     — bulkhead depth cue
  ```

- [ ] **3.3 Verify the lighting contract and commit it.**

  ```bash
  env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gselect battle_world_3d -gexit
  git add src/battle/presentation/battle_world_3d.tscn src/battle/presentation/industrial_room_3d.tscn test/integration/test_battle_world_3d.gd
  git commit -m "feat: add mobile battle lighting hierarchy"
  ```

  Expected: the test exits zero and the commit includes only the two scene resources and their integration contract.

## Task 4: Validate real pixels at minimum, reference, and 4K output sizes

**Files:**

- Create then delete: `_battle_lighting_probe.gd`
- Modify then restore: `project.godot`

- [ ] **4.1 Add a temporary autoload framebuffer probe.**

  Add `_battle_lighting_probe.gd` at the project root and temporarily register it as an autoload in `project.godot`. It must boot the real lab scene, resize the real window, wait for rendered frames, write framebuffer pixels, and then quit:

  ```gdscript
  extends Node

  const OUTPUTS := [Vector2i(1280, 800), Vector2i(1920, 1080), Vector2i(3840, 2160)]

  func _ready() -> void:
      await get_tree().process_frame
      get_tree().change_scene_to_file("res://src/battle/presentation/battle_hud_lab.tscn")
      for _frame in 120:
          await get_tree().process_frame
      for output_size in OUTPUTS:
          DisplayServer.window_set_size(output_size)
          for _frame in 24:
              await get_tree().process_frame
          var image := get_viewport().get_texture().get_image()
          var path := "/tmp/mars-battle-lighting-%dx%d.png" % [output_size.x, output_size.y]
          image.save_png(path)
          print("captured=%s viewport=%s" % [path, get_viewport().get_visible_rect().size])
      get_tree().quit()
  ```

  Do not use `--headless`; this test judges rendered pixels.

- [ ] **4.2 Run and inspect the windowed probe.**

  ```bash
  env HOME=/tmp/mars-godot-probe '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --path "$PWD"
  ```

  Inspect all three PNGs at native size and enlarged crops. Acceptance criteria:

  - 1280×800 retains the whole hero/action composition without clipping; it is uniformly scaled and letterboxed vertically as designed.
  - 1920×1080 reads as a dimensional room: the left/right wall planes, floor, ceiling fixtures, drones, and rear bulkhead are distinguishable; the fill has not become a broad front wash.
  - 3840×2160 keeps the same UI proportions as the 1920×1080 composition rather than producing microscopic HUD elements.
  - Across all sizes, room seams remain closed, hero cards do not obscure the drones, and the HUD remains above the 3D world.

- [ ] **4.3 Remove all temporary probe artifacts.**

  Remove the root script, its `.uid` sidecar if Godot generated one, and the temporary `project.godot` autoload entry using `apply_patch`. Then confirm the repository has no probe artifacts:

  ```bash
  rg --files -g '*battle_lighting_probe*' -g '*battle_lighting_probe*.uid'
  git diff -- project.godot
  ```

  Expected: `rg` produces no paths, and `project.godot` has no probe-only diff.

## Task 5: Full regression and handoff

**Files:**

- No production changes.

- [ ] **5.1 Run the full automated suite.**

  ```bash
  env HOME=/tmp/mars-godot-home '/Applications/Godot 4.7.app/Contents/MacOS/Godot' --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gexit
  ```

  Expected: all tests pass with exit code zero. Note documented Godot shutdown diagnostics separately from failures.

- [ ] **5.2 Perform a final scope audit.**

  ```bash
  git status --short
  git log --oneline -3
  git show --stat --oneline HEAD
  ```

  Confirm the three implementation commits are independently reviewable:

  1. `fix: clear battle stage and seal room shell`
  2. `test: lock battle UI 4k scaling policy`
  3. `feat: add mobile battle lighting hierarchy`

  Do not stage or modify the unrelated actor/theme/hub work already present in the checkout.
