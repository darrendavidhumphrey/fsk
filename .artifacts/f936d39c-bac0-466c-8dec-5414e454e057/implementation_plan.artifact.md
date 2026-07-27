# Conditional "Best Fit" for CheckerBoardScene

I will update the `CheckerBoardScene` to automatically scale and center its geometry when using the dynamic `OrthoViewDelegate`, while maintaining its original origin-centered behavior for perspective views like `OrbitViewDelegate`.

## Proposed Changes

### [Examples]

#### [MODIFY] [checkerboard_scene.dart](file:///C:/Users/darre/StudioProjects/fsk/example/lib/checkerboard_scene.dart)
- Update `drawVBO` to detect if the active delegate is an `OrthoViewDelegate`.
- If using Ortho:
    - Apply a centering translation: `(viewportSize.width / 2, viewportSize.height / 2)`.
    - Apply a scaling factor to make the `500x500` quad fill the viewport: `(viewportSize.width / 500, viewportSize.height / 500)`.
- If using any other delegate (like Orbit):
    - Use the standard `mvMatrix` without extra transformations.

## Verification Plan

### Manual Verification
- **Ortho View**: Verify the checkerboard pattern fills the screen and is centered.
- **Orbit View**: Verify the checkerboard remains at the world origin where the camera is looking.
