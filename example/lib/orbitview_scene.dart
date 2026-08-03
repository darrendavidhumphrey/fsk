import 'package:flutter/material.dart' hide Matrix4;
import 'package:fsk/fsk.dart';

class OrbitViewScene extends FskFrameScene {
  OrbitViewScene({super.navigationDelegate}) {
    clearColor = Colors.white;
    useBoxFitLayout = false;

    // 1. Create quad with grid material in one go
    final gridQuad = FskQuad.centered(
      'grid',
      this,
      const Size(500, 500),
      shaderMaterial: FskShaderMaterial.grid,
    );

    // 2. Configure persistent uniforms once
    final uniforms = gridQuad.uniforms as GridUniforms;
    uniforms.scale = 0.1; // 1 unit = 1mm
    uniforms.setResolution(500, 500); // Scale grid to world units

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

    isReady = true;
    navigationDelegate?.updateSceneMatrices(force: true);
  }
}
