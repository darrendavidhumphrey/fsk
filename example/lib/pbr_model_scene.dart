import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

class PbrModelScene extends FskFrameScene {
  FskGroup? modelRoot;

  PbrModelScene({super.navigationDelegate}) {
    init();
  }

  void init() async {
    clearColor = const Color(0xFF101015);
    use2DLayout = false; // Perspective 3D mode

    try {
      modelRoot = await FskGltfLoader.load(
        'assets/SciFiHelmet/glTF/SciFiHelmet.gltf',
        this,
      );

      if (modelRoot != null) {
        // SciFiHelmet is small (~1 unit). Scale significantly for orbit camera.
        modelRoot!.transformable.scale = Vector3.all(200.0);
        modelRoot!.transformable.position = Vector3(0, 0, 0);
        
        // Add to the hierarchy
        addNode(modelRoot!);
        
        // Enable diagnostic mode to verify visibility
        _enableDiagnosticMode(modelRoot!);
        
        isReady = true;
        navigationDelegate?.updateSceneMatrices(force: true);
      }
    } catch (e, s) {
      logError("Error loading PBR model: $e\n$s");
    }
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (!isReady) return;
    
    // We override to apply custom per-frame logic (like lighting) before drawing the graph
    if (modelRoot != null) {
      _updateLightPosition(modelRoot!, Vector3(500, 500, 500));
    }
    
    super.drawScene(renderPass, transients);
  }

  void _enableDiagnosticMode(FskSceneObject node) {
    if (node is FskRenderableObject) {
      node.rebuildPipelineIfNeeded();
      final uniforms = node.uniforms;
      if (uniforms is PbrUniforms) {
        // Mode 4: Solid Magenta silhouette to confirm geometry placement
        uniforms.debugMode = 4.0;
      }
    }
    
    if (node is FskGroup) {
      for (final child in node.children) {
        _enableDiagnosticMode(child);
      }
    }
  }

  void _updateLightPosition(FskSceneObject node, Vector3 pos) {
    if (node is FskRenderableObject) {
      final uniforms = node.uniforms;
      if (uniforms is PbrUniforms) {
        uniforms.setValueSilent(PbrUniforms.kLightPosKey, pos);
      }
    }
    
    if (node is FskGroup) {
      for (final child in node.children) {
        _updateLightPosition(child, pos);
      }
    }
  }
}
