import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'base_uniforms.dart';

class SimpleTextureUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String _kModulateColorKey = 'modulateColor';
  static const String _kSamplerUniformName = 'uSampler';

  // --- Default Layout Value Constants ---
  static const Color _kDefaultModulateColor = Color(0xFFFFFFFF);

  // --- Buffer Structure Allocation Constants ---
  static const int _kFragmentDataFloatCount = 4;

  // --- Texture State ---
  gpu.Texture? _texture;

  SimpleTextureUniforms({super.vertexShader, super.fragmentShader}) {
    // Establish initialization values inside the string data store
    this[_kModulateColorKey] = _kDefaultModulateColor;
  }

  // --- Type-Safe Public Setters ---
  set modulateColor(Color val) => this[_kModulateColorKey] = val;
  set texture(gpu.Texture? val) => _texture = val;

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(_kFragmentDataFloatCount);

    // Pack modulateColor into the first 4 floats (16 bytes)
    packColor(fragmentData, 0, this[_kModulateColorKey] as Color);

    return fragmentData;
  }

  /// Extends the base bind pass to handle the texture binding step.
  @override
  void bind(gpu.RenderPass renderPass) {
    // 1. Run the base routine to bind Vertex matrices and block configurations
    super.bind(renderPass);

    // 2. Safely look up and bind the texture sampling asset
    if (_texture != null && fragmentShader != null) {
      final gpu.UniformSlot textureSlot = fragmentShader!.getUniformSlot(_kSamplerUniformName);
      renderPass.bindTexture(textureSlot, _texture!);
    }
  }
}
