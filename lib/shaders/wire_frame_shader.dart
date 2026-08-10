import 'dart:ui';
import 'package:vector_math/vector_math.dart' as vm;
import 'base_uniforms.dart';

class WireFrameUniforms extends BaseUniforms {
  // --- Dictionary Key Constants ---
  static const String kLightPosKey = 'uLightPos';
  static const String kAmbientLightKey = 'uAmbientLight';
  static const String kDiffuseLightKey = 'uDiffuseLight';
  static const String kSpecularLightKey = 'uSpecularLight';
  static const String kMaterialAmbientKey = 'uMaterialAmbient';
  static const String kMaterialDiffuseKey = 'uMaterialDiffuse';
  static const String kMaterialSpecularKey = 'uMaterialSpecular';
  static const String kMaterialShininessKey = 'uMaterialShininess';
  static const String kOutlineEnabledKey = 'uOutlineEnabled';
  static const String kDrawFillKey = 'uDrawFill';
  static const String kOutlineColorKey = 'uOutlineColor';
  static const String kOutlineWidthKey = 'uOutlineWidth';

  @override
  String get vertexBlockName => 'WireFrameVertexUniforms';
  @override
  String get fragmentBlockName => 'WireFrameFragmentUniforms';

  WireFrameUniforms({super.vertexShader, super.fragmentShader}) {
    this[kLightPosKey] = vm.Vector3(100.0, 100.0, 200.0);
    this[kAmbientLightKey] = const Color(0xFFFFFFFF);
    this[kDiffuseLightKey] = const Color(0xFFFFFFFF);
    this[kSpecularLightKey] = const Color(0xFFFFFFFF);
    this[kMaterialAmbientKey] = const Color(0xFFFFFFFF);
    this[kMaterialDiffuseKey] = const Color(0xFFFFFFFF);
    this[kMaterialSpecularKey] = const Color(0xFFFFFFFF);
    this[kMaterialShininessKey] = 32.0;
    this[kOutlineEnabledKey] = true;
    this[kDrawFillKey] = true;
    this[kOutlineColorKey] = const Color(0xFF000000);
    this[kOutlineWidthKey] = 1.0;
  }

  // --- Type-Safe Public Setters ---
  set lightPos(vm.Vector3 val) => this[kLightPosKey] = val;
  set ambientLight(Color val) => this[kAmbientLightKey] = val;
  set diffuseLight(Color val) => this[kDiffuseLightKey] = val;
  set specularLight(Color val) => this[kSpecularLightKey] = val;
  set materialAmbient(Color val) => this[kMaterialAmbientKey] = val;
  set materialDiffuse(Color val) => this[kMaterialDiffuseKey] = val;
  set materialSpecular(Color val) => this[kMaterialSpecularKey] = val;
  set materialShininess(double val) => this[kMaterialShininessKey] = val;
  set outlineEnabled(bool val) => this[kOutlineEnabledKey] = val;
  set drawFill(bool val) => this[kDrawFillKey] = val;
  set outlineColor(Color val) => this[kOutlineColorKey] = val;
  set outlineWidth(double val) => this[kOutlineWidthKey] = val;

  @override
  void serializeFragmentData() {
    fragmentData.clear();
    fragmentData.packVector3(valuesMap[kLightPosKey]);
    fragmentData.packColor(valuesMap[kAmbientLightKey]);
    fragmentData.packColor(valuesMap[kDiffuseLightKey]);
    fragmentData.packColor(valuesMap[kSpecularLightKey]);
    fragmentData.packColor(valuesMap[kMaterialAmbientKey]);
    fragmentData.packColor(valuesMap[kMaterialDiffuseKey]);
    fragmentData.packColor(valuesMap[kMaterialSpecularKey]);
    fragmentData.packColor(valuesMap[kOutlineColorKey]);
    fragmentData.packDouble(valuesMap[kMaterialShininessKey]);
    fragmentData.packBool(valuesMap[kOutlineEnabledKey]);
    fragmentData.packBool(valuesMap[kDrawFillKey]);
    fragmentData.packDouble(valuesMap[kOutlineWidthKey]);
  }
}
