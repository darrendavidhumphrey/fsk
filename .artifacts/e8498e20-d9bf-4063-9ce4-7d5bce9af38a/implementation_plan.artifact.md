# Decentralized Factory Registration for Frame Scene Objects

Move `Frame*Data` definitions and their factory registration logic into the corresponding `Fsk*` scene object files. This improves modularity by co-locating all logic related to a specific object type (parsing, data representation, and building).

## User Review Required

> [!IMPORTANT]
> - `FskSceneObjectFactory` will be moved from `frame_scene_builder.dart` to `frame_data.dart` to centralize factory management and avoid circular dependencies.
> - `FrameQuadData`, `FrameGroupData`, and `FrameTextData` will be moved from `frame_data.dart` to `fsk_quad.dart`, `fsk_group.dart`, and `fsk_bitmap_text.dart` respectively.
> - `FskQuad`, `FskGroup`, and `FskBitmapText` will each implement a `static void register()` method.
> - `FrameSceneParser.registerDefaults()` and `FrameSceneBuilder.registerDefaults()` will now call these `register()` methods.

## Proposed Changes

### [frames]

#### [MODIFY] [frame_data.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/frames/frame_data.dart)
- [NEW] Move `FskSceneObjectFactory` and `FskSceneObjectBuilder` from `frame_scene_builder.dart` to this file.
- [DELETE] Remove `FrameQuadData`, `FrameGroupData`, and `FrameTextData`.

#### [MODIFY] [frame_scene_builder.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/frames/frame_scene_builder.dart)
- [DELETE] Remove `FskSceneObjectFactory` and `FskSceneObjectBuilder` (they moved to `frame_data.dart`).
- Update `registerDefaults()` to call the new registration methods.

#### [MODIFY] [frame_scene_parser.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/frames/frame_scene_parser.dart)
- Update `registerDefaults()` to call `FskQuad.register()`, `FskGroup.register()`, and `FskBitmapText.register()`.

### [scene_graph]

#### [MODIFY] [fsk_quad.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/scene_graph/fsk_quad.dart)
- [NEW] Move `FrameQuadData` class here.
- Add `static void register()` to `FskQuad` that registers the parser and builder.

#### [MODIFY] [fsk_group.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/scene_graph/fsk_group.dart)
- [NEW] Move `FrameGroupData` class here.
- Add `static void register()` to `FskGroup` that registers the parser and builder.

#### [MODIFY] [fsk_bitmap_text.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/scene_graph/fsk_bitmap_text.dart)
- [NEW] Move `FrameTextData` class here.
- Add `static void register()` to `FskBitmapText` that registers the parser and builder.

## Verification Plan

### Automated Tests
- Verify that the scene still builds correctly using existing examples.
- Ensure no circular dependencies are introduced that break compilation.

### Manual Verification
- Run `example/lib/frame_scene_example.dart`.
