import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class CADCanvasScene extends FskFrameScene {
  CADCanvasScene({super.navigationDelegate}) {
    clearColor = Colors.white;
    useBoxFitLayout = false;

    // Restore grid
    makeCanvas();
    makeHandlebars();

    isReady = true;
  }

  void makeCanvas() {
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
  }

  void makeHandlebars() {
    List<Vector3> handles = [
      Vector3(50, 50, 0),
      Vector3(150, 50, 0),
      Vector3(150, 150, 0),
      Vector3(50, 150, 0),
      ];
    final handlebarSize = const Size.square(10);
    for (int i=0; i < handles.length; i++) {
      addNode(FskQuad.atPoint("handle_$i", handles[i],handlebarSize, this, textureId: FSK().textureManager.solidTextureId, modulateColor: Colors.black));
    }
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget, gpu.HostBuffer transients) {
    if (!isReady) return;
    super.drawScene(commandBuffer, renderTarget, transients);
  }
}
