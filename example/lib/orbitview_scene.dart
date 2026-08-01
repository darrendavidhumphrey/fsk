import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class OrbitViewScene extends FskFrameScene {
  OrbitViewScene({super.navigationDelegate}) {
    clearColor = Colors.white;

    // TODO: Need or slop?
    use2DLayout = false; // Disable 2D fitting/centering for this 3D scene

    // Simplified creation using sugar for a centered 2D quad
    final gridQuad = FskQuad.centered(
      'grid',
      this,
      const Size(500, 500),
    );

    // Simplified material assignment
    gridQuad.material = FskShaderMaterial.grid;

    // Use high-level interface to add to scene graph
    addNode(gridQuad);

    isReady = true;
    navigationDelegate?.updateSceneMatrices(force: true);
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (!isReady) return;

    // Apply procedural uniform logic for the grid before drawing
    final gridQuad = findNode<FskQuad>('grid');
    if (gridQuad != null) {
      final uniforms = gridQuad.renderer.uniforms;
      if (uniforms is GridUniforms) {
        uniforms.scale = 0.1;
        uniforms.setResolution(1000, 1000);
        uniforms.majorLineSpacingMM = 25;
        uniforms.minorLineSpacingMM = 5;
        uniforms.majorLineThickness = 0.25;
        uniforms.minorLineThickness = 0.125;
        uniforms.mmLineThickness = 0.025;
        uniforms.majorLineColor = Colors.red;
        uniforms.minorLineColor = Colors.blue;
        uniforms.mmLineColor = Colors.grey;
      }
    }

    // Now call super to handle the actual drawing of the graph
    super.drawScene(renderPass, transients);
  }
}
