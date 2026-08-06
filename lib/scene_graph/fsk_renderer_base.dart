import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../gpu/fsk_shader_material.dart';
import '../gpu/fsk_texture_manager.dart';
import '../shaders/base_uniforms.dart';
import 'fsk_depth_state.dart';

import '../logging.dart';

abstract class FskRendererBase extends ChangeNotifier with LoggableClass {
  FskRendererBase();

  /// Optional custom material configuration
  FskShaderMaterial? shaderMaterial;

  /// The active uniform block for this renderer
  BaseUniforms? _uniforms;
  BaseUniforms? get uniforms => _uniforms;
  set uniforms(BaseUniforms? value) {
    if (_uniforms == value) return;
    _uniforms = value;
    pipeLineNeedsRebuild = true;
    notifyListeners(); // Renderer is now a ChangeNotifier
  }

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
