import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../gpu/fsk_shader_material.dart';
import '../gpu/fsk_texture_manager.dart';
import '../shaders/base_uniforms.dart';
import 'fsk_depth_state.dart';

abstract class FskRendererBase {
  FskRendererBase();

  /// Optional custom material configuration
  FskShaderMaterial? shaderMaterial;

  /// The active uniform block for this renderer
  BaseUniforms? uniforms;

  // Pointer to the texture in the texture manager
  FskTextureInfo? textureInfo;

  final FskDepthState depthState = FskDepthState();
  bool pipeLineNeedsRebuild = true;

  void setTexture(FskTextureInfo? info) {
    textureInfo = info;
  }

  void draw(
      gpu.RenderPass renderPass,
      gpu.HostBuffer transients,
      Matrix4 pMatrix,
      Matrix4 mvMatrix,
      Size viewportSize,
      );

  // All renderers must support a pipeline rebuild
  void rebuildPipeline();
}
