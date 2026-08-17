import 'package:flutter/material.dart' show Colors;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../scene_graph/fsk_group.dart';
import '../scene_graph/fsk_mtsdf_text.dart';
import '../scene_graph/fsk_rectangular_solid.dart';
import '../scene_graph/fsk_text_alignment.dart';
import '../shaders/materials.dart';
import '../shaders/lighting_shader.dart';
import '../bitmap_fonts/bitmap_font_manager.dart';
import '../geometry/reference_box.dart';
import '../ui/screen_space_overlay.dart';

/// A concrete implementation of a screen-space overlay that displays an interactive view cube.
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
    useBoxFitLayout = false;

    // Ensure the MTSDF font is loaded.
    await BitmapFontManager().createFontFromFile(
      "isocpeur-mtsdf",
      "Isocpeur-mtsdf.xml",
      "Isocpeur-mtsdf.png",
      generateMipmaps: true,
    );

    // Create a container group for the entire cube assembly.
    final cubeRoot = FskGroup('cube_root', this);

    // Standard CAD View Cube orientation (Z-up, X-right, Y-forward)
    cubeRoot.transformable.rotation = vm.Vector3.zero();

    // Generate geometry and labels.
    cubeRoot.addNodes(_generateGeometry());
    cubeRoot.addNodes(_generateLabels());

    addNode(cubeRoot);
  }

  List<FskRectangularSolid> _generateGeometry() {
    final List<FskRectangularSolid> solids = [];
    final double halfSize = cubeSize / 2.0;
    final double cornerSize = cubeSize / 4.0;
    final double midSize = cubeSize - (2 * cornerSize);
    final double cornerOffset = halfSize - (cornerSize / 2.0);

    // 1. Central Face Segments (mapped to Z-up axes)
    final faceData = [
      ('RIGHT', vm.Vector3(cornerOffset, 0, 0), vm.Vector3(cornerSize, midSize, midSize)),
      ('LEFT', vm.Vector3(-cornerOffset, 0, 0), vm.Vector3(cornerSize, midSize, midSize)),
      ('BACK', vm.Vector3(0, cornerOffset, 0), vm.Vector3(midSize, cornerSize, midSize)),
      ('FRONT', vm.Vector3(0, -cornerOffset, 0), vm.Vector3(midSize, cornerSize, midSize)),
      ('TOP', vm.Vector3(0, 0, cornerOffset), vm.Vector3(midSize, midSize, cornerSize)),
      ('BOTTOM', vm.Vector3(0, 0, -cornerOffset), vm.Vector3(midSize, midSize, cornerSize)),
    ];

    for (final data in faceData) {
      solids.add(_createSolid(data.$1, data.$2, data.$3));
    }

    // 2. Corner Cube Segments (8 combinations)
    for (int i = 0; i < 8; i++) {
      final pos = vm.Vector3(
        (i & 1 == 0 ? -1 : 1) * cornerOffset,
        (i & 2 == 0 ? -1 : 1) * cornerOffset,
        (i & 4 == 0 ? -1 : 1) * cornerOffset,
      );
      solids.add(FskRectangularSolid.cube(
        id: 'Corner_$i',
        scene: this,
        center: pos,
        size: cornerSize,
      ));
    }

    // 3. Edge Connector Segments (12 segments)
    final edgeDims = [
      vm.Vector3(midSize, cornerSize, cornerSize), // X-parallel
      vm.Vector3(cornerSize, midSize, cornerSize), // Y-parallel
      vm.Vector3(cornerSize, cornerSize, midSize), // Z-parallel
    ];

    for (int axis = 0; axis < 3; axis++) {
      for (int i = 0; i < 4; i++) {
        final s1 = (i & 1 == 0 ? -1 : 1) * cornerOffset;
        final s2 = (i & 2 == 0 ? -1 : 1) * cornerOffset;
        
        vm.Vector3 pos;
        if (axis == 0) {
          pos = vm.Vector3(0, s1, s2);
        } else if (axis == 1) {
          pos = vm.Vector3(s1, 0, s2);
        } else {
          pos = vm.Vector3(s1, s2, 0);
        }

        solids.add(_createSolid('Edge_${axis}_$i', pos, edgeDims[axis]));
      }
    }

    // Configure all solids with consistent shading.
    for (final solid in solids) {
      solid.renderer.rebuildPipeline();
      final u = solid.uniforms as LightingUniforms;
      u.isHeadlamp = true; 
      u.kd = vm.Vector3(0.7, 0.7, 0.7);
      u.ld = vm.Vector3(1.0, 1.0, 1.0);
      solid.renderer.uniforms?.applyMaterial(GlMaterial(Colors.grey, Colors.grey, Colors.black, 32.0));
    }

    return solids;
  }

  FskRectangularSolid _createSolid(String name, vm.Vector3 center, vm.Vector3 dims) {
    return FskRectangularSolid.rectangular(
      id: name,
      scene: this,
      center: center,
      dimensions: dims,
    );
  }

  List<FskMtsdfText> _generateLabels() {
    final double dist = cubeSize / 2 + 0.5;
    final double width = cubeSize * (2 / 3);
    final double h = width / 2;
    final font = BitmapFontManager().getFont("isocpeur-mtsdf") ?? BitmapFontManager().defaultFont!;

    final List<FskMtsdfText> labels = [];

    // Helper to define face orientation: Label, Origin, X-Axis, Y-Axis, Normal
    void addLabel(String text, vm.Vector3 origin, vm.Vector3 x, vm.Vector3 y, vm.Vector3 n) {
      labels.add(FskMtsdfText(
        '${text}_text', this,
        ReferenceBox(origin, x, y, n),
        font: font, text: text,
      ));
    }

    // Z-up Label Mappings synchronized with the polar fallback logic:
    // FRONT (-Y face): Origin at (-h, -dist, -h), X=(width, 0, 0), Y=(0, 0, width), Normal=(0, -1, 0)
    addLabel("FRONT", vm.Vector3(-h, -dist, -h), vm.Vector3(width, 0, 0), vm.Vector3(0, 0, width), vm.Vector3(0, -1, 0));
    // BACK (+Y face): Origin at (h, dist, -h), X=(-width, 0, 0), Y=(0, 0, width), Normal=(0, 1, 0)
    addLabel("BACK", vm.Vector3(h, dist, -h), vm.Vector3(-width, 0, 0), vm.Vector3(0, 0, width), vm.Vector3(0, 1, 0));
    // TOP (+Z face): Origin at (-h, -h, dist), X=(width, 0, 0), Y=(0, width, 0), Normal=(0, 0, 1)
    addLabel("TOP", vm.Vector3(-h, -h, dist), vm.Vector3(width, 0, 0), vm.Vector3(0, width, 0), vm.Vector3(0, 0, 1));
    // BOTTOM (-Z face): Origin at (-h, -h, -dist), X=(width, 0, 0), Y=(0, width, 0), Normal=(0, 0, -1)
    addLabel("BOTTOM", vm.Vector3(-h, -h, -dist), vm.Vector3(width, 0, 0), vm.Vector3(0, width, 0), vm.Vector3(0, 0, -1));
    // RIGHT (+X face): Origin at (dist, -h, -h), X=(0, width, 0), Y=(0, 0, width), Normal=(1, 0, 0)
    addLabel("RIGHT", vm.Vector3(dist, -h, -h), vm.Vector3(0, width, 0), vm.Vector3(0, 0, width), vm.Vector3(1, 0, 0));
    // LEFT (-X face): Origin at (-dist, h, -h), X=(0, -width, 0), Y=(0, 0, width), Normal=(-1, 0, 0)
    addLabel("LEFT", vm.Vector3(-dist, h, -h), vm.Vector3(0, -width, 0), vm.Vector3(0, 0, width), vm.Vector3(-1, 0, 0));

    for (final label in labels) {
      label.textColor = Colors.black;
      label.horizontalJustification = TextHorizontalJustification.center;
      label.verticalJustification = TextVerticalJustification.center;
      label.renderer.premultiplyAlpha = false;
      label.setDepthState(
        depthTestEnabled: true,
        depthWriteEnabled: false,
        depthCompareOperation: gpu.CompareFunction.lessEqual,
      );
      label.renderer.rebuildPipeline();
    }

    return labels;
  }
}
