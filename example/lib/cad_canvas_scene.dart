import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

const double _gridSize = 500;

class CADCanvasScene extends FskScene {
  CADCanvasScene({super.navigationDelegate,super.clearColor=Colors.white}) {
    skinSize = const Size(_gridSize, _gridSize);
  }

  @override
  Future<void> onInit() async {
    await super.onInit();
    useBoxFitLayout = false;

    FskQuad gridQuad = makeCanvas();
    makeOutline(gridQuad);
    makeHandlebars();
    await loadAxis();
  }

  FskQuad makeCanvas() {
    // 1. Create quad with grid material in one go
    var gridQuad = FskQuad.centered(
      'grid',
      this,
      const Size(_gridSize, _gridSize),
      shaderMaterial: FskShaderMaterial.grid,
    );

    // 2. Configure persistent uniforms once
    final uniforms = gridQuad.uniforms as GridUniforms;
    uniforms.scale = 0.1; // 1 unit = 1mm
    uniforms.setResolution(_gridSize, _gridSize); // Scale grid to world units

    uniforms.majorLineSpacingMM = 25;
    uniforms.minorLineSpacingMM = 5;
    uniforms.majorLineThickness = 0.25;
    uniforms.minorLineThickness = 0.1;
    uniforms.mmLineThickness = 0.05;

    uniforms.majorLineColor = Colors.red;
    uniforms.minorLineColor = Colors.blue;
    uniforms.mmLineColor = Colors.grey;

    // 3. Add to scene graph
    addNode(gridQuad);
    return gridQuad;
  }

  void makeHandlebars() {
    List<Vector3> handles = [
      Vector3(50, 50, 0),
      Vector3(150, 50, 0),
      Vector3(150, 150, 0),
      Vector3(50, 150, 0),
    ];
    final handlebarSize = const Size.square(10);
    FskGroup group = FskGroup("handles", this);
    for (int i = 0; i < handles.length; i++) {
      logInfo("  Creating handle $i...");
      var q = FskQuad.atPoint(
        "handle_$i",
        handles[i],
        handlebarSize,
        this,
        textureId: FSK().textureManager.solidTextureId,
        modulateColor: Colors.black,
      );
      q.setDepthState(depthTestEnabled: false, depthWriteEnabled: false);
      group.addNode(q);
    }
    addNode(group);
  }

  void makeOutline(FskQuad gridQuad) {
    // Make thick line that follows the outline of the mesh quad
    addNode(
      MeshFactory.meshFromQuadOutline(
        id:'outer_edge',
        parentScene: this,
        quad:gridQuad.quad,
        thickness: 4,
        color: Colors.blue,
      ),
    );
  }

  // Create custom materials for the axes
  void createMaterials() {
    Color specular = Colors.black;
    const double shine = 5;
    FSK().materials.addMaterial(
      "X",
      GlMaterial(Colors.red, Colors.red, specular, shine),
    );

    FSK().materials.addMaterial(
      "Y",
      GlMaterial(Colors.green, Colors.green, specular, shine),
    );

    FSK().materials.addMaterial(
      "Z",
      GlMaterial(Colors.blue, Colors.blue, specular, shine),
    );
  }

  Future<void> loadAxis() async {
    // Create custom materials so axis is not white
    createMaterials();

    final axisModel = await WavefrontObjModel.loadFromAssets(
      assetFile: 'assets/3D/Axis/xyzaxis.obj',
      parentScene: this,
      sceneId: 'axis',
      onModelLoaded: (model) {
        final uniforms = model.mesh.uniforms as LightingUniforms;
        uniforms.lightPos = Vector3(500, 500, 500);

        // Scale up the axis
        model.scale = Vector3.all(2);
        // Move it to the corner of the grid
        model.position = Vector3(-_gridSize / 2, -_gridSize / 2, 0);
        // rotate the axis 90 degrees about the Y axis
        model.rotation = Vector3(0, 0, radians(90));
      },
    );

    // Add the axis root to the scene graph
    addNode(axisModel);
  }
}