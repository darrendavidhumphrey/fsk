import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

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
    final cubeSize = 10.0;
  //  addNodes( _generateViewCubeQuads(this, cubeSize) );
    addNodes( _makeCubeLabels(this, cubeSize) );
  }
}




/// Generates the complex structure of cubes and rectangular solids.
List<FskRectangularSolid> _generateViewCubeQuads(FskSceneBase parentScene,double totalSize) {
  final List<FskRectangularSolid> solids = [];
  final double halfTotalSize = totalSize / 2.0;

  // Define sizes
  final double cornerSize = totalSize / 4.0;
  final double centralSize = totalSize - (2 * cornerSize);
  final double edgeLength = centralSize;
  final double halfCornerSize = cornerSize / 2.0;
  final double centerPatchOffset1 = halfTotalSize - cornerSize / 2;
  final double centerPatchOffset2 = -halfTotalSize + cornerSize / 2;

  // --- 1. Central Solids (6 of them) ---

  //Solid(this.faces, this.name, this.dimensions) {

  // Parallel to x axis
  solids.add(
    FskRectangularSolid.rectangular(
      scene: parentScene,
      center: Vector3(centerPatchOffset1, 0, 0),
      dimensions: Vector3(cornerSize, edgeLength, edgeLength),
      id: 'Central Cube+X',
    ),
  );

  solids.add(
    FskRectangularSolid.rectangular(
      scene: parentScene,
      center: Vector3(centerPatchOffset2, 0, 0),
      dimensions: Vector3(cornerSize, edgeLength, edgeLength),
      id: 'Central Cube-X',
    ),
  );

  // Parallel to y axis
  solids.add(
    FskRectangularSolid.rectangular(
      scene: parentScene,
      center: Vector3(0, centerPatchOffset1, 0),
      dimensions: Vector3(edgeLength, cornerSize, edgeLength),
      id: 'Central Cube+Y',
    ),
  );

  solids.add(
    FskRectangularSolid.rectangular(
      scene: parentScene,
      center: Vector3(0, centerPatchOffset2, 0),
      dimensions: Vector3(edgeLength, cornerSize, edgeLength),
      id: 'Central Cube-Y',
    ),
  );

  // Parallel to z axis
  solids.add(
    FskRectangularSolid.rectangular(
      scene: parentScene,
      center: Vector3(0, 0, centerPatchOffset1),
      dimensions: Vector3(edgeLength, edgeLength, cornerSize),
      id: 'Central Cube+Z',
    ),
  );

  solids.add(
    FskRectangularSolid.rectangular(
      scene: parentScene,
      center: Vector3(0, 0, centerPatchOffset2),
      dimensions: Vector3(edgeLength, edgeLength, cornerSize),
      id: 'Central Cube-Z',
    ),
  );

  // --- 2. Corner Cubes (8 of them) ---

  for (int i = 0; i < 8; i++) {
    final double xSign = (i & 1) == 0 ? -1.0 : 1.0;
    final double ySign = (i & 2) == 0 ? -1.0 : 1.0;
    final double zSign = (i & 4) == 0 ? -1.0 : 1.0;

    final double cornerOffset = halfTotalSize - halfCornerSize;

    final Vector3 cornerPosition = Vector3(
      xSign * cornerOffset,
      ySign * cornerOffset,
      zSign * cornerOffset,
    );

    solids.add(
        FskRectangularSolid.cube(scene: parentScene,center: cornerPosition, size: cornerSize, id: 'Corner Cube ${i + 1}',)
    );
  }

  // --- 3. Edge Rectangular Solids (12 of them) ---

  final double edgeOffset = halfTotalSize - halfCornerSize - (edgeLength / 2.0);

  // Edges parallel to X-axis (4 of them)
  final double edgeThicknessY = cornerSize;
  final double edgeThicknessZ = cornerSize;
  for (int i = 0; i < 4; i++) {
    final double ySign = (i & 1) == 0 ? -1.0 : 1.0;
    final double zSign = (i & 2) == 0 ? -1.0 : 1.0;

    Vector3 edgePosition = Vector3(0, ySign * edgeOffset, zSign * edgeOffset);
    edgePosition += Vector3(
      0,
      (centralSize / 2) * ySign,
      (centralSize / 2) * zSign,
    );
    solids.add(
      FskRectangularSolid.rectangular(
        scene: parentScene,
        center: edgePosition,
        dimensions: Vector3(edgeLength, edgeThicknessY, edgeThicknessZ),
        id: 'Edge Solid X-${i + 1}',
      ),
    );
  }

  // Edges parallel to Y-axis (4 of them)
  final double edgeThicknessX = cornerSize;
  final double edgeThicknessZY = cornerSize;
  for (int i = 0; i < 4; i++) {
    final double xSign = (i & 1) == 0 ? -1.0 : 1.0;
    final double zSign = (i & 2) == 0 ? -1.0 : 1.0;

    Vector3 edgePosition = Vector3(xSign * edgeOffset, 0, zSign * edgeOffset);
    edgePosition += Vector3(
      (centralSize / 2) * xSign,
      0,
      (centralSize / 2) * zSign,
    );
    solids.add(
      FskRectangularSolid.rectangular(
        scene: parentScene,
        center:edgePosition,
        dimensions: Vector3(edgeThicknessX, edgeLength, edgeThicknessZY),
        id:'Edge Solid Y-${i + 1}',
      ),
    );
  }

  // Edges parallel to Z-axis (4 of them)
  final double edgeThicknessXtoZ = cornerSize;
  final double edgeThicknessYtoZ = cornerSize;
  for (int i = 0; i < 4; i++) {
    final double xSign = (i & 1) == 0 ? -1.0 : 1.0;
    final double ySign = (i & 2) == 0 ? -1.0 : 1.0;

    Vector3 edgePosition = Vector3(xSign * edgeOffset, ySign * edgeOffset, 0);
    edgePosition += Vector3(
      (centralSize / 2) * xSign,
      (centralSize / 2) * ySign,
      0,
    );
    solids.add(
      FskRectangularSolid.rectangular(
        scene: parentScene,
        center:edgePosition,
        dimensions: Vector3(edgeThicknessXtoZ, edgeThicknessYtoZ, edgeLength),
        id:'Edge Solid Z-${i + 1}',
      ),
    );
  }

  return solids;
}

List<FskBitmapText> _makeCubeLabels(FskSceneBase parentScene, double cubeSize) {
  double textDistance = cubeSize / 2 + 0.1;
  final double textWidth = cubeSize * (2 / 3);
  final double topTextWidth = cubeSize / 2;

  List<FskBitmapText> cubeLabels = [];

  final font = BitmapFontManager().defaultFont!;
  // TOP Face (+Z)
  final topRefBox = ReferenceBox(
    Vector3(-topTextWidth / 2, cubeSize/2, textDistance),
    Vector3(topTextWidth, 0, 0),
    Vector3(0, cubeSize, 0),
    Vector3(0, 0, 1),
  );

  final topLabel = FskBitmapText(
    "TOP",
    parentScene,
    topRefBox,
    font:font,
    text: "TOP",
    horizontalJustification: TextHorizontalJustification.center,
    verticalJustification: TextVerticalJustification.center,
  );
  cubeLabels.add(topLabel);

  // BOTTOM Face (-Z)
  final bottomRefBox = ReferenceBox(
    Vector3(-textWidth / 2, -cubeSize / 2, -textDistance),
    Vector3(textWidth, 0, 0),
    Vector3(0, -cubeSize, 0),
    Vector3(0, 0, -1),
  );

  final bottomLabel = FskBitmapText(
    "BOTTOM",
    parentScene,
    bottomRefBox,
    font:font,
    text:"BOTTOM",
    horizontalJustification: TextHorizontalJustification.center,
    verticalJustification: TextVerticalJustification.center,
  );
  cubeLabels.add(bottomLabel);

  // FRONT Face (-Y)
  final frontRefBox = ReferenceBox(
    Vector3(-textWidth / 2, -textDistance, cubeSize / 2),
    Vector3(textWidth, 0, 0),
    Vector3(0, 0, cubeSize),
    Vector3(0, -1, 0),
  );

  final frontLabel = FskBitmapText(
    "FRONT",
    parentScene,
    frontRefBox,
    font: font,
    text: "FRONT",
    horizontalJustification: TextHorizontalJustification.center,
    verticalJustification: TextVerticalJustification.center,
  );
  cubeLabels.add(frontLabel);

  // BACK Face (+Y)
  final backRefBox = ReferenceBox(
    Vector3(textWidth / 2, textDistance, cubeSize / 2),
    Vector3(-textWidth, 0, 0),
    Vector3(0, 0, cubeSize),
    Vector3(0, 1, 0),
  );

  final backLabel = FskBitmapText(
    "BACK",
    parentScene,
    backRefBox,
    font: font,
    text: "BACK",
    horizontalJustification: TextHorizontalJustification.center,
    verticalJustification: TextVerticalJustification.center,
  );
  cubeLabels.add(backLabel);

  // RIGHT Face (+X)
  final rightRefBox = ReferenceBox(
    Vector3(textDistance, -textWidth / 2, cubeSize / 2),
    Vector3(0, textWidth, 0),
    Vector3(0, 0, cubeSize),
    Vector3(1, 0, 0),
  );
  final rightLabel = FskBitmapText(
    "RIGHT",
    parentScene,
    rightRefBox,
    font: font,
    text: "RIGHT",
    horizontalJustification: TextHorizontalJustification.center,
    verticalJustification: TextVerticalJustification.center,
  );
  cubeLabels.add(rightLabel);

  // LEFT Face (-X)
  final leftRefBox = ReferenceBox(
    Vector3(-textDistance, textWidth / 2, cubeSize / 2),
    Vector3(0, -textWidth, 0),
    Vector3(0, 0, cubeSize),
    Vector3(-1, 0, 0),
  );
  var leftLabel = FskBitmapText(
    "LEFT",
    parentScene,
    leftRefBox,
    font: font,
    text: "LEFT",
    horizontalJustification: TextHorizontalJustification.center,
    verticalJustification: TextVerticalJustification.center,
  );
  cubeLabels.add(leftLabel);

  return cubeLabels;
}