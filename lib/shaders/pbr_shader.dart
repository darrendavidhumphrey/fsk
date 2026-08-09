import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk_singleton.dart';
import 'base_uniforms.dart';

class PbrUniforms extends BaseUniforms {
  static const String kLightPosKey = 'uLightPos';
  static const String kWorldLightPosKey = 'worldLightPos';
  static const String kBaseColorFactorKey = 'uBaseColorFactor';
  static const String kRoughnessFactorKey = 'uRoughnessFactor';
  static const String kMetallicFactorKey = 'uMetallicFactor';
  static const String kDebugModeKey = 'uDebugMode';
  static const String kIsHeadlampKey = 'isHeadlamp';

  @override
  String get vertexBlockName => 'PbrVertexUniforms';
  @override
  String get fragmentBlockName => 'PbrFragmentUniforms';

  gpu.Texture? normalMap;
  gpu.Texture? metallicRoughnessMap;

  PbrUniforms({super.vertexShader, super.fragmentShader}) {
    this[kLightPosKey] = Vector3.zero();
    this[kWorldLightPosKey] = Vector3(200.0, 200.0, 200.0);
    this[kBaseColorFactorKey] = Vector3(1.0, 1.0, 1.0);
    this[kRoughnessFactorKey] = 1.0;
    this[kMetallicFactorKey] = 1.0;
    this[kDebugModeKey] = 0.0;
    this[kIsHeadlampKey] = false;
  }

  set lightPos(Vector3 val) => this[kWorldLightPosKey] = val;
  set baseColorFactor(Vector3 val) => this[kBaseColorFactorKey] = val;
  set roughnessFactor(double val) => this[kRoughnessFactorKey] = val;
  set metallicFactor(double val) => this[kMetallicFactorKey] = val;
  set debugMode(double val) => this[kDebugModeKey] = val;
  set isHeadlamp(bool val) => this[kIsHeadlampKey] = val;

  @override
  void onUpdate(Size viewportSize) {
    if (this[kIsHeadlampKey] as bool) {
      // Light is at the camera in View Space
      this[kLightPosKey] = Vector3.zero();
      return;
    }

    // Transform light position into View Space every frame.
    final dynamic worldPosVal = valuesMap[kWorldLightPosKey];
    final Vector3 worldPos = (worldPosVal is Vector3) ? worldPosVal : Vector3(200, 200, 200);
    
    final Vector4 viewPos = mvMatrixLocal.transform(Vector4(worldPos.x, worldPos.y, worldPos.z, 1.0));
    this[kLightPosKey] = Vector3(viewPos.x, viewPos.y, viewPos.z);
  }

  @override
  void copyFrom(BaseUniforms other) {
    super.copyFrom(other);
    if (other is PbrUniforms) {
      normalMap = other.normalMap;
      metallicRoughnessMap = other.metallicRoughnessMap;
    }
  }

  @override
  void bindAdditionalTextures(gpu.RenderPass renderPass) {
    if (fragmentShader == null) return;
    final dummy = FSK().textureManager.transparentTexture!;
    renderPass.bindTexture(fragmentShader!.getUniformSlot('uNormalMap'), normalMap ?? dummy, sampler: samplerOptions);
    renderPass.bindTexture(fragmentShader!.getUniformSlot('uMetallicRoughnessMap'), metallicRoughnessMap ?? dummy, sampler: samplerOptions);
  }

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packVector3(valuesMap[kLightPosKey]);
    fragmentData.packVector3(valuesMap[kBaseColorFactorKey]);
    fragmentData.packDouble(valuesMap[kRoughnessFactorKey]);
    fragmentData.packDouble(valuesMap[kMetallicFactorKey]);
    fragmentData.packDouble(valuesMap[kDebugModeKey]);
  }
}
