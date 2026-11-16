# Windle NPC artwork (VILLAGE-29)

The village uses real AI-created pixel-art sprites, not procedurally generated map graphics.

- `npc_walk_atlas.b64`: base64 encoded 48×440 PNG; five actors stacked vertically in 4-row, 3-column walking sheets. Each frame is 16×22 source pixels. One actor occupies 88 source rows. Direction order: down / left / right / up. Frame order: step / idle / step.
- `npc_idle_atlas.b64`: base64 encoded 200×48 PNG; five detailed idle sprites in horizontal 40×48 cells, cropped at runtime to remove transparent padding.
- Actor order in both sheets: Ricky, Meri, Goro, village elder, herbalist Sena.
- Three recruitable characters load through `characters.json` + `SpriteAnimation.decode_frames`. Elder and herbalist use local map textures in `vertical_slice.gd`.
- The battle sprites and existing save game keys are unchanged.

QA: `tests/test_ui_smoke.gd` verifies five unique field textures and all 60 directional frames. `tests/capture_village.gd` renders three real Xvfb screenshots for visual comparison, including western NPCs.
