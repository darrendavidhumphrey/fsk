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
      // 🟢 NORMAL RENDERING: Load the actual SciFi Helmet
      modelRoot = await FskGltfLoader.load('assets/SciFiHelmet/glTF/SciFiHelmet.gltf', this);

      if (modelRoot != null) {
        // Optimized scale for standard orbit distance
        modelRoot!.transformable.scale = Vector3.all(100.0);
        modelRoot!.transformable.position = Vector3(0, 0, 0);
        
        addNode(modelRoot!);
        
        isReady = true;
        navigationDelegate?.updateSceneMatrices(force: true);
      }
    } catch (e, s) {
      logError("Error loading PBR model: $e\n$s");
    }
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (!isReady || modelRoot == null) return;

    super.setupScissor(renderPass);

    // CUSTOM DRAW OVERLOAD: 
    // Manual recursive draw using standard camera matrices
    _manualDraw(modelRoot!, renderPass, transients, pMatrix, mvMatrix);
  }

  void _manualDraw(FskSceneObject node, gpu.RenderPass renderPass, gpu.HostBuffer transients, Matrix4 proj, Matrix4 view) {
    bool isVisible = true;
    Matrix4 currentMv = view;

    if (node is FskRenderableObject) {
      if (!node.visible) return;
      isVisible = node.visible;
      // Hierarchical math: Post-multiplication (View * Local)
      currentMv = view.clone()..multiply(node.transformable.getTransform());
    }

    if (!isVisible) return;

    if (node is FskIndexedMesh) {
      final renderer = node.renderer;
      renderer.rebuildPipeline();
      
      final uniforms = renderer.uniforms!;
      uniforms.onUpdate(viewportSize);
      
      // RESTORED: Use actual scene matrices
      uniforms.mvMatrix = currentMv;
      uniforms.pMatrix = proj;
      
      // Update light position silently for this sub-mesh
      if (uniforms is PbrUniforms) {
        // Place light slightly above and to the right of the camera for a standard "Key Light" feel
        uniforms.setValueSilent(PbrUniforms.kLightPosKey, Vector3(200, 200, 0));
        uniforms.setValueSilent(PbrUniforms.kDebugModeKey, 0.0); // Full PBR
      }

      uniforms.bind(renderPass, transients);

      FSK().activatePipeline(renderer.pipelineKey!, renderPass, renderer.layout);
      renderer.vbo.bind(renderPass);
      renderer.ibo.bind(renderPass);
      renderer.ibo.drawTrianglesIndexed(renderPass);
    }

    if (node is FskGroup) {
      for (final child in node.children) {
        _manualDraw(child, renderPass, transients, proj, currentMv);
      }
    }
  }
}
