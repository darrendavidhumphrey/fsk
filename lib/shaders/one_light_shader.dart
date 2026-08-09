import 'dart:typed_data';
import 'dart:ui';
import 'package:vector_math/vector_math.dart';
import 'base_uniforms.dart';
import 'materials.dart';

class OneLightUniforms extends BaseUniforms {
  static const String kLightPosKey = 'uLightPos';
  static const String kAmbientLightKey = 'uAmbientLight';
  static const String kDiffuseLightKey = 'uDiffuseLight';
  static const String kSpecularLightKey = 'uSpecularLight';
  static const String kMaterialAmbientKey = 'uMaterialAmbient';
  static const String kMaterialDiffuseKey = 'uMaterialDiffuse';
  static const String kMaterialSpecularKey = 'uMaterialSpecular';
  static const String kMaterialShininessKey = 'kMaterialShininess';

  @override
  String get vertexBlockName => 'OneLightVertexUniforms';
  @override
  String get fragmentBlockName => 'OneLightFragmentUniforms';

  OneLightUniforms({super.vertexShader, super.fragmentShader}) {
    this[kLightPosKey] = Vector3(100.0, 100.0, 200.0);
    this[kAmbientLightKey] = const Color(0xFFFFFFFF);
    this[kDiffuseLightKey] = const Color(0xFFFFFFFF);
    this[kSpecularLightKey] = const Color(0xFFFFFFFF);
    this[kMaterialAmbientKey] = const Color(0xFFFFFFFF);
    this[kMaterialDiffuseKey] = const Color(0xFFFFFFFF);
    this[kMaterialSpecularKey] = const Color(0xFFFFFFFF);
    this[kMaterialShininessKey] = 32.0;
  }

  set lightPos(Vector3 val) => this[kLightPosKey] = val;
  set ambientLight(Color val) => this[kAmbientLightKey] = val;
  set diffuseLight(Color val) => this[kDiffuseLightKey] = val;
  set specularLight(Color val) => this[kSpecularLightKey] = val;
  set materialAmbient(Color val) => this[kMaterialAmbientKey] = val;
  set materialDiffuse(Color val) => this[kMaterialDiffuseKey] = val;
  set materialSpecular(Color val) => this[kMaterialSpecularKey] = val;
  set materialShininess(double val) => this[kMaterialShininessKey] = val;

  @override
  void applyMaterial(GlMaterial material) {
    this[kMaterialAmbientKey] = material.ambient;
    this[kMaterialDiffuseKey] = material.diffuse;
    this[kMaterialSpecularKey] = material.specular;
    this[kMaterialShininessKey] = material.shininess;
  }

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(BaseUniforms.kFragmentDataFloatCount);
    int offset = 0;
    offset = packVector3(fragmentData, offset, valuesMap[kLightPosKey]);
    offset = packColor(fragmentData, offset, valuesMap[kAmbientLightKey]);
    offset = packColor(fragmentData, offset, valuesMap[kDiffuseLightKey]);
    offset = packColor(fragmentData, offset, valuesMap[kSpecularLightKey]);
    offset = packColor(fragmentData, offset, valuesMap[kMaterialAmbientKey]);
    offset = packColor(fragmentData, offset, valuesMap[kMaterialDiffuseKey]);
    offset = packColor(fragmentData, offset, valuesMap[kMaterialSpecularKey]);
    offset = packDouble(fragmentData, offset, valuesMap[kMaterialShininessKey]);
    return fragmentData;
  }
}
