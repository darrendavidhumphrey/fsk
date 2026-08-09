import 'dart:typed_data';
import 'dart:ui';
import 'base_uniforms.dart';

class GridUniforms extends BaseUniforms {
  static const String _kMajorLineColorKey = 'majorLineColor';
  static const String _kMinorLineColorKey = 'minorLineColor';
  static const String _kMmLineColorKey = 'mmLineColor';
  static const String _kResolutionWidthKey = 'resolutionWidth';
  static const String _kResolutionHeightKey = 'resolutionHeight';
  static const String _kScaleKey = 'scale';
  static const String _kMajorLineSpacingMMKey = 'majorLineSpacingMM';
  static const String _kMinorLineSpacingMMKey = 'minorLineSpacingMM';
  static const String _kMajorLineThicknessKey = 'majorLineThickness';
  static const String _kMinorLineThicknessKey = 'minorLineThickness';
  static const String _kMmLineThicknessKey = 'mmLineThickness';

  @override
  String get vertexBlockName => 'GridVertexUniforms';
  @override
  String get fragmentBlockName => 'GridFragmentUniforms';

  GridUniforms({super.vertexShader, super.fragmentShader}) {
    this[_kMajorLineColorKey] = const Color(0xFFFFFFFF);
    this[_kMinorLineColorKey] = const Color(0xFFB0B0B0);
    this[_kMmLineColorKey] = const Color(0xFF606060);
    this[_kResolutionWidthKey] = 1000.0;
    this[_kResolutionHeightKey] = 1000.0;
    this[_kScaleKey] = 1.0;
    this[_kMajorLineSpacingMMKey] = 25.0;
    this[_kMinorLineSpacingMMKey] = 5.0;
    this[_kMajorLineThicknessKey] = 0.25;
    this[_kMinorLineThicknessKey] = 0.1;
    this[_kMmLineThicknessKey] = 0.05;
  }

  set majorLineColor(Color val) => this[_kMajorLineColorKey] = val;
  set minorLineColor(Color val) => this[_kMinorLineColorKey] = val;
  set mmLineColor(Color val) => this[_kMmLineColorKey] = val;

  void setResolution(double width, double height) {
    setValueSilent(_kResolutionWidthKey, width);
    setValueSilent(_kResolutionHeightKey, height);
  }

  set scale(double val) => this[_kScaleKey] = val;
  set majorLineSpacingMM(double val) => this[_kMajorLineSpacingMMKey] = val;
  set minorLineSpacingMM(double value) => this[_kMinorLineSpacingMMKey] = value;
  set majorLineThickness(double val) => this[_kMajorLineThicknessKey] = val;
  set minorLineThickness(double val) => this[_kMinorLineThicknessKey] = val;
  set mmLineThickness(double val) => this[_kMmLineThicknessKey] = val;

  @override
  void onUpdate(Size viewportSize) {
    if (valuesMap[_kResolutionWidthKey] == null) {
      setResolution(viewportSize.width, viewportSize.height);
    }
  }

  @override
  Float32List serializeFragmentData() {
    final Float32List fragmentData = Float32List(BaseUniforms.kFragmentDataFloatCount);
    int offset = 0;
    offset = packColor(fragmentData, offset, valuesMap[_kMajorLineColorKey]);
    offset = packColor(fragmentData, offset, valuesMap[_kMinorLineColorKey]);
    offset = packColor(fragmentData, offset, valuesMap[_kMmLineColorKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kResolutionWidthKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kResolutionHeightKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kScaleKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kMajorLineSpacingMMKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kMinorLineSpacingMMKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kMajorLineThicknessKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kMinorLineThicknessKey]);
    offset = packDouble(fragmentData, offset, valuesMap[_kMmLineThicknessKey]);
    return fragmentData;
  }
}
