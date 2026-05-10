# Patch 11 (Advanced Shapes) Merge Notes

This patch has a few conflict-prone areas when replayed onto newer upstream code.

## High-risk merge artifacts to check

1. `blocksuite/affine/widgets/edgeless-selected-rect/src/edgeless-auto-complete.ts`
   - Symptom: runtime error `this._mapPositionByFlip is not a function`.
   - Cause: conflict resolution kept calls to `_mapPositionByFlip(...)` but dropped the method definition.
   - Required checks:
     - `_mapPositionByFlip(position, shape)` exists on `EdgelessAutoComplete`.
     - `_computeLine(...)` compiles cleanly and defines `startConnectionPosition` before use.
     - `PointLocation` is imported if `PointLocation.fromVec(...)` is used.

2. `blocksuite/affine/widgets/edgeless-selected-rect/src/mindmap-shape-panel.ts`
   - Symptom: settings-dependent runtime errors or wrong palette behavior.
   - Required checks:
     - Do not reference variables that are out of scope inside `_addShape(...)` (for example `behavior`).
     - Avoid writing optional style fields as `undefined` in `crud.updateElement(...)` payloads.
     - For `mindmapSubTopic`, preserve rounded appearance (`radius` should stay `0.5`).

3. `blocksuite/affine/gfx/shape/src/element-renderer/shape/utils.ts`
   - Symptom: `createLinearGradient` finite-number crash.
   - Required check:
     - Guard gradient creation when width/height are non-finite and fall back to solid fill.

## Verification checklist after merge

1. Create next shape from a non-advanced shape (e.g. rounded rectangle).
   - Expect: no console errors; connector preview and placement work.
2. Create mindmap sub topic from next-shape panel.
   - Expect: rounded sub-topic shape, not square.
3. Enable mindmap next-color behavior and add multiple children.
   - Expect: no rendering crash and behavior matches selected mode.
4. Toggle collapse/expand on advanced mindmap/container shapes.
   - Expect: plus/minus control remains visible and connectors update.

## Practical merge tip

When resolving conflicts in `edgeless-auto-complete.ts`, prefer taking one side wholesale for each logical block (helper methods + call sites + imports) instead of line-level blending. Partial blending in this file is the main source of broken runtime states.
