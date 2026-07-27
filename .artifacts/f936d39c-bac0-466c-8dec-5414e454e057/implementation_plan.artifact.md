# Debugging Quad Positioning in Hierarchical Scenes

The user reports that quads in `GameScreenTest2.xml` and `GameScreenTest3.xml` are drawing at incorrect locations. Specifically, `Question8_BackBox` draws at the same location as `Question1_BackBox`, while its sibling text objects draw correctly.

## Research Findings

1.  **Matrix Isolation**: I've already added matrix cloning in `FrameGroupNode.draw` and `FrameScene.drawScene`, which should prevent matrix leakage between sibling nodes.
2.  **Origin Logic**: I've unified the origin logic for quads to use `ReferenceBox` with a `top` origin, which correctly maps the `screenRect` coordinates into group-relative space.
3.  **Correctness of Text**: The fact that `Question8_Text` is in the correct place confirms that the hierarchical translation of the `Question8` group is working correctly for some objects.
4.  **Suspicion of Uniform/State Leakage**: If the quad is drawing at Question 1's location despite a correct matrix being passed to it, it suggests that either the `mvMatrix` is being ignored, or the underlying uniform data is being corrupted or shared improperly.

## Proposed Changes

### [FSK Engine]

#### [MODIFY] [frame_scene_nodes.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/frames/frame_scene_nodes.dart)
- I will add a diagnostic log to `FrameGroupNode.draw` that captures the IDs and matrices being passed down. Since I cannot see standard output, I will temporarily modify the `draw` method to append this info to a global string that I can later dump to an artifact.
- I will further strengthen the matrix isolation by explicitly clearing the `mvMatrix` stack at the start of each frame if it's being used improperly.

#### [MODIFY] [fsk_quad.dart](file:///C:/Users/darre/StudioProjects/fsk/lib/scene_graph/fsk_quad.dart)
- I will add a check to ensure `rebuildIfNeeded` is called correctly and that the VBO is indeed unique.

## Verification Plan

### Automated Tests
- I will use the `task` tool to create a small diagnostic script that prints the scene hierarchy and calculated matrices to an artifact.

### Manual Verification
- Ask the user to check the diagnostic output to see if the matrices for Question 8 are indeed correct.
