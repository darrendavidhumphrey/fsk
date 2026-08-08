import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter/material.dart' show Colors;

/// A concrete implementation of a screen-space overlay that displays the view cube
class ViewCubeOverlay extends ScreenSpaceOverlay {
  final double cubeSize;
  ViewCubeOverlay({
    required super.id,
    required this.cubeSize,
    super.top,
    super.right,
    super.left,
    super.bottom,
    required super.screenSpaceSize,
    super.interceptInput,
    super.navigationDelegate,
  });

  @override
  Future<void> onInit() async {
    await super.onInit();
    // Overlays typically don't use box-fit layout as they are explicitly sized
    useBoxFitLayout = false;

    final double actualSize = cubeSize;

    // Create a container group for the entire cube so we can rotate it easily
    final cubeRoot = FskGroup('cube_root', this);
    // Rotate 180 degrees around Y to correct orientation relative to OrbitViewDelegate
    cubeRoot.transformable.rotation = vm.Vector3(0, vm.radians(180), vm.radians(180));

    // Add both the cube geometry and the labels to the group
    final solids = _generateViewCubeQuads(this, actualSize);
    for (var solid in solids) {
      solid.renderer.rebuildPipeline();
      final uniforms = solid.uniforms as LightingUniforms;
      uniforms.lightPos = vm.Vector3(200, 200, 200);
      uniforms.kd = vm.Vector3(0.7, 0.7, 0.7);
      uniforms.ld = vm.Vector3(1.0, 1.0, 1.0);

    }
    cubeRoot.addNodes(solids);

    final labels = _makeCubeLabels(this, actualSize);

    cubeRoot.addNodes(labels);


    addNode(cubeRoot);

    // Focus the camera on the center of the cube
    if (navigationDelegate is OrbitViewDelegate) {
      final delegate = navigationDelegate as OrbitViewDelegate;
      delegate.setViewDistance(actualSize * 2.5);
    }
  }
}

/// Generates the structure of cubes and rectangular solids in standard RH space.
List<FskRectangularSolid> _generateViewCubeQuads(
    FskSceneBase parentScene, double totalSize) {
  final List<FskRectangularSolid> solids = [];
  final double halfTotalSize = totalSize / 2.0;
  final double cornerSize = totalSize / 4.0;
  final double centralSize = totalSize - (2 * cornerSize);
  final double edgeLength = centralSize;
  final double halfCornerSize = cornerSize / 2.0;
  final double centerPatchOffset = halfTotalSize - (cornerSize / 2.0);

  // --- 1. Central Solids (Faces) ---
  solids.add(FskRectangularSolid.rectangular(
    scene: parentScene, center: vm.Vector3(centerPatchOffset, 0, 0),
    dimensions: vm.Vector3(cornerSize, edgeLength, edgeLength), id: 'Face RIGHT',
  ));
  solids.add(FskRectangularSolid.rectangular(
    scene: parentScene, center: vm.Vector3(-centerPatchOffset, 0, 0),
    dimensions: vm.Vector3(cornerSize, edgeLength, edgeLength), id: 'Face LEFT',
  ));
  solids.add(FskRectangularSolid.rectangular(
    scene: parentScene, center: vm.Vector3(0, centerPatchOffset, 0),
    dimensions: vm.Vector3(edgeLength, cornerSize, edgeLength), id: 'Face TOP',
  ));
  solids.add(FskRectangularSolid.rectangular(
    scene: parentScene, center: vm.Vector3(0, -centerPatchOffset, 0),
    dimensions: vm.Vector3(edgeLength, cornerSize, edgeLength), id: 'Face BOTTOM',
  ));
  solids.add(FskRectangularSolid.rectangular(
    scene: parentScene, center: vm.Vector3(0, 0, centerPatchOffset),
    dimensions: vm.Vector3(edgeLength, edgeLength, cornerSize), id: 'Face FRONT',
  ));
  solids.add(FskRectangularSolid.rectangular(
    scene: parentScene, center: vm.Vector3(0, 0, -centerPatchOffset),
    dimensions: vm.Vector3(edgeLength, edgeLength, cornerSize), id: 'Face BACK',
  ));

  // --- 2. Corner Cubes ---
  for (int i = 0; i < 8; i++) {
    final double xSign = (i & 1) == 0 ? -1.0 : 1.0;
    final double ySign = (i & 2) == 0 ? -1.0 : 1.0;
    final double zSign = (i & 4) == 0 ? -1.0 : 1.0;
    solids.add(FskRectangularSolid.cube(
      scene: parentScene, center: vm.Vector3(xSign * (halfTotalSize - halfCornerSize), ySign * (halfTotalSize - halfCornerSize), zSign * (halfTotalSize - halfCornerSize)),
      size: cornerSize, id: 'Corner $i',
    ));
  }

  // --- 3. Edge Solids ---
  final double edgeOffset = halfTotalSize - halfCornerSize;
  // Edges parallel to X
  for (int i = 0; i < 4; i++) {
    final double ySign = (i & 1) == 0 ? -1.0 : 1.0;
    final double zSign = (i & 2) == 0 ? -1.0 : 1.0;
    solids.add(FskRectangularSolid.rectangular(
      scene: parentScene, center: vm.Vector3(0, ySign * edgeOffset, zSign * edgeOffset),
      dimensions: vm.Vector3(edgeLength, cornerSize, cornerSize), id: 'EdgeX $i',
    ));
  }
  // Edges parallel to Y
  for (int i = 0; i < 4; i++) {
    final double xSign = (i & 1) == 0 ? -1.0 : 1.0;
    final double zSign = (i & 2) == 0 ? -1.0 : 1.0;
    solids.add(FskRectangularSolid.rectangular(
      scene: parentScene, center: vm.Vector3(xSign * edgeOffset, 0, zSign * edgeOffset),
      dimensions: vm.Vector3(cornerSize, edgeLength, cornerSize), id: 'EdgeY $i',
    ));
  }
  // Edges parallel to Z
  for (int i = 0; i < 4; i++) {
    final double xSign = (i & 1) == 0 ? -1.0 : 1.0;
    final double ySign = (i & 2) == 0 ? -1.0 : 1.0;
    solids.add(FskRectangularSolid.rectangular(
      scene: parentScene, center: vm.Vector3(xSign * edgeOffset, ySign * edgeOffset, 0),
      dimensions: vm.Vector3(cornerSize, cornerSize, edgeLength), id: 'EdgeZ $i',
    ));
  }

  return solids;
}

List<FskBitmapText> _makeCubeLabels(FskSceneBase parentScene, double cubeSize) {
  final double textDistance = cubeSize / 2 + 0.1;
  final double textWidth = cubeSize * (2 / 3);
  final double h = textWidth / 2;
  final font = BitmapFontManager().defaultFont!;

  List<FskBitmapText> cubeLabels = [];

  // FRONT (+Z)
  cubeLabels.add(FskBitmapText(
    "FRONT", parentScene,
    ReferenceBox(vm.Vector3(-h, -h, textDistance), vm.Vector3(textWidth, 0, 0), vm.Vector3(0, textWidth, 0), vm.Vector3(0, 0, 1)),
    font: font, text: "FRONT",
  ));

  // BACK (-Z)
  cubeLabels.add(FskBitmapText(
    "BACK", parentScene,
    ReferenceBox(vm.Vector3(h, -h, -textDistance), vm.Vector3(-textWidth, 0, 0), vm.Vector3(0, textWidth, 0), vm.Vector3(0, 0, -1)),
    font: font, text: "BACK",
  ));

  // TOP (+Y)
  cubeLabels.add(FskBitmapText(
    "TOP", parentScene,
    ReferenceBox(vm.Vector3(-h, textDistance, h), vm.Vector3(textWidth, 0, 0), vm.Vector3(0, 0, -textWidth), vm.Vector3(0, 1, 0)),
    font: font, text: "TOP",
  ));

  // BOTTOM (-Y)
  cubeLabels.add(FskBitmapText(
    "BOTTOM", parentScene,
    ReferenceBox(vm.Vector3(-h, -textDistance, -h), vm.Vector3(textWidth, 0, 0), vm.Vector3(0, 0, textWidth), vm.Vector3(0, -1, 0)),
    font: font, text: "BOTTOM",
  ));

  // RIGHT (+X)
  cubeLabels.add(FskBitmapText(
    "RIGHT", parentScene,
    ReferenceBox(vm.Vector3(textDistance, -h, h), vm.Vector3(0, 0, -textWidth), vm.Vector3(0, textWidth, 0), vm.Vector3(1, 0, 0)),
    font: font, text: "RIGHT",
  ));

  // LEFT (-X)
  cubeLabels.add(FskBitmapText(
    "LEFT", parentScene,
    ReferenceBox(vm.Vector3(-textDistance, -h, -h), vm.Vector3(0, 0, textWidth), vm.Vector3(0, textWidth, 0), vm.Vector3(-1, 0, 0)),
    font: font, text: "LEFT",
  ));

  for (var label in cubeLabels) {
    label.textColor = Colors.black;
    label.horizontalJustification = TextHorizontalJustification.center;
    label.verticalJustification = TextVerticalJustification.center;
    label.setDepthState(depthTestEnabled: true, depthWriteEnabled: false);
  }

  return cubeLabels;
}
