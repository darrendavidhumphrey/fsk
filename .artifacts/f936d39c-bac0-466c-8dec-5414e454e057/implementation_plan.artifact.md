# Add BoxFit support to OrthoViewDelegate

This plan outlines the changes needed to add `BoxFit`-like functionality to `OrthoViewDelegate`, allowing scenes to easily scale and position content within the viewport.

## User Review Required

> [!IMPORTANT]
> The new `createBoxFitMatrix` method will assume that the content's origin is at `(0,0)` (local space) by default. If your content is centered at `(0,0)`, you may need to apply a pre-translation or we can add a parameter to handle it.

## Proposed Changes

### [FSK Engine]

#### [MODIFY] [ortho_view_delegate.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/ui/navigation_delegates/ortho_view_delegate.dart)
- Define `OrthoBoxFit` enum: `none`, `fitWidth`, `fitHeight`, `fill`.
- Add `boxFit` property to `OrthoViewDelegate`, defaulting to `none`.
- Add `createBoxFitMatrix(Size contentSize)` method. This method will:
    - Return `Matrix4.identity()` if `boxFit` is `none`.
    - Calculate a scale and translation based on the selected `boxFit`, the provided `contentSize`, and the current viewport size (`_viewRect`).
    - `fitWidth`: Scales content to match viewport width and centers it vertically.
    - `fitHeight`: Scales content to match viewport height and centers it horizontally.
    - `fill`: Stretches content to exactly fill the viewport.

## Verification Plan

### Automated Tests
- I will verify the matrix calculations manually against expected values for common scenarios (e.g., fitting a square content into a widescreen viewport).

### Manual Verification
- Update `CheckerBoardScene` to use the new `createBoxFitMatrix` method and verify it renders correctly with different `boxFit` options.
