import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

const double _gridSize = 500;

class CADCanvasScene extends FskFrameScene {

  late FskQuad _gridQuad;
  CADCanvasScene({super.navigationDelegate}) {
    frameSize = const Size(_gridSize, _gridSize);
  }

  @override
  Future<void> init() async {
    if (initStarted) return;
    await super.init();
    try {
      logInfo("CADCanvasScene.init: Starting...");
      clearColor = Colors.white;
      useBoxFitLayout = false;

      logInfo("CADCanvasScene.init: making canvas...");
      makeCanvas();
      
      logInfo("CADCanvasScene.init: making handlebars...");
      makeHandlebars();
      
      logInfo("CADCanvasScene.init: making outline (SKIPPED)...");
       makeOutline();
      
      logInfo("CADCanvasScene.init: loading axis (SKIPPED)...");
      await loadAxis();

      logInfo("CADCanvasScene.init: Setting isReady = true");
      isReady = true;
    } catch (e, s) {
      logError("CRITICAL Error in CADCanvasScene.init: $e\n$s");
      isReady = true;
    }
  }

  void makeCanvas() {
    // 1. Create quad with grid material in one go
    _gridQuad = FskQuad.centered(
      'grid',
      this,
      const Size(_gridSize, _gridSize),
      shaderMaterial: FskShaderMaterial.grid,
    );

    // 2. Configure persistent uniforms once
    final uniforms = _gridQuad.uniforms as GridUniforms;
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
    addNode(_gridQuad);
  }

  void makeHandlebars() {
    logInfo("CADCanvasScene.makeHandlebars: Starting...");
    List<Vector3> handles = [
      Vector3(50, 50, 0),
      Vector3(150, 50, 0),
      Vector3(150, 150, 0),
      Vector3(50, 150, 0),
      ];
    final handlebarSize = const Size.square(10);
    FskGroup group = FskGroup("handles", this);
    for (int i=0; i < handles.length; i++) {
      logInfo("  Creating handle $i...");
      var q = FskQuad.atPoint("handle_$i", handles[i],handlebarSize, this, textureId: FSK().textureManager.solidTextureId, modulateColor: Colors.black);
      q.setDepthState(depthTestEnabled: false, depthWriteEnabled: false);
      group.addNode(q);
    }
    addNode(group);
    logInfo("CADCanvasScene.makeHandlebars: Done.");
  }

  void makeOutline() {
    // Make thick line that follows the outline of the mesh quad
    // The thick line is returned as a list of polylines
    List<Polyline> outlines = createThickOutline3DFromQuad(_gridQuad.quad, 4);

    // Convert the outlines to a FskMesh object and add to the scene graph
    addNode(MeshFactory.meshFromColorOutlines('outer_edge', this, outlines, Colors.blue));
  }

  Future<void> loadAxis() async {
    Color defaultSpecular = Colors.black;
    const double defaultShininess = 5;
    FSK().materials.addMaterial(
      "X",
      GlMaterial(Colors.red, Colors.red, defaultSpecular, defaultShininess),
    );

    FSK().materials.addMaterial(
      "Y",
      GlMaterial(Colors.green, Colors.green, defaultSpecular, defaultShininess),
    );

    FSK().materials.addMaterial(
      "Z",
      GlMaterial(Colors.blue, Colors.blue, defaultSpecular, defaultShininess),
    );

    logInfo("CADCanvasScene.loadAxis: Starting model load...");
    FskGroup axisModel = await WavefrontObjModel.load(
      'assets/3D/Axis/xyzaxis.obj',
      this,
      'axis',
    );
    logInfo("CADCanvasScene.loadAxis: Model loaded successfully.");

    final mesh = axisModel.findNode<FskIndexedMesh>('axis_correction.axis');
    if (mesh != null) {
      logInfo("CADCanvasScene.loadAxis: Configuring axis uniforms...");
      final LightingUniforms uniforms = LightingUniforms();
      mesh.uniforms = uniforms;
      uniforms.lightPos = Vector3(500, 500, 500);

      var textureInfo = FSK().textureManager.solidTextureInfo;

      uniforms.texture = textureInfo.texture;
      uniforms.samplerOptions = textureInfo.samplerOptions;
    }

    axisModel.scale = Vector3.all(2);
    axisModel.position = Vector3(-_gridSize / 2, -_gridSize / 2, 0);
    axisModel.rotation = Vector3(0, 0, radians(90));

    // Add the axis root to the scene graph
    addNode(axisModel);
  }
}
