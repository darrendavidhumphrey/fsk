import 'dart:ui';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

import '../fsk_singleton.dart';
import '../geometry/reference_box.dart';
import '../geometry/mesh_hit_tester.dart';
import '../gpu/fsk_shader_material.dart';
import '../shaders/base_uniforms.dart';
import '../shaders/simple_texture_shader.dart';
import '../util.dart';
import '../skins/skin_data.dart';
import '../skins/skin_scene_parser.dart';

import 'fsk_scene_object.dart';
import 'fsk_scene_base.dart';
import 'fsk_transformable.dart';
import 'fsk_depth_state.dart';
import 'fsk_quads_renderer.dart';

class SkinQuadData extends SkinObjectData {
  final String texture;
  final Rect screenRect;
  final Rect textureRect;
  final bool premultiplyAlpha;
  final String? modulateColor;

  SkinQuadData({
    required super.id,
    required super.visible,
    super.shader,
    required super.shaderParams,
    required this.texture,
    required this.screenRect,
    required this.textureRect,
    this.modulateColor,
    this.premultiplyAlpha = false,
  });
}

/// A class that manages the geometry and rendering for a single textured quad
class FskQuad extends Fsk2DRenderableObject with FskTransformableMixin, FskDepthStateMixin {
  // The texture coordinates for the quad
  late final Rect _textureRect;

  /// Object that renders the quads
  final FskQuadsRenderer _renderer = FskQuadsRenderer();

  @override
  FskQuadsRenderer get renderer => _renderer;

  // The quad geometry
  vm.Quad _quad = vm.Quad();
  vm.Quad get quad => _quad;

  bool _premultiplyAlpha = true;
  Color _modulateColor = const Color(0xFFFFFFFF);

  @override
  void updateUniforms(BaseUniforms uniforms) {
    super.updateUniforms(uniforms);
    if (uniforms is SimpleTextureUniforms) {
      final modulate = _premultiplyAlpha
          ? Color.fromARGB(
              (_modulateColor.a * 255).round(),
              (_modulateColor.r * _modulateColor.a * 255).round(),
              (_modulateColor.g * _modulateColor.a * 255).round(),
              (_modulateColor.b * _modulateColor.a * 255).round(),
            )
          : _modulateColor;
      uniforms.setModulateColor(modulate);
    }
  }

  static void registerWithFactories() {
    SkinObjectDataFactory.register('quad', (node, anchors, parseObject) {
      final String? shaderName = node.getAttribute('shader');
      final Map<String, String> shaderParamsMap = SkinSceneParser.parseShaderParams(node.getAttribute('shaderParams'));
      return SkinQuadData(
        id: node.getAttribute('id')!,
        visible: SkinSceneParser.isVisible(node),
        texture: node.getAttribute('texture')!,
        screenRect: SkinSceneParser.parseRect(node.getAttribute('screenRect')!),
        textureRect: SkinSceneParser.parseTextureRect(node.getAttribute('textureRect')),
        premultiplyAlpha: node.getAttribute('premultiplyAlpha') == 'true',
        shader: shaderName,
        modulateColor: node.getAttribute('modulateColor'),
        shaderParams: shaderParamsMap,
      );
    });

    FskSceneObjectFactory.register(SkinQuadData, (scene, data, createNode) {
      final quadData = data as SkinQuadData;
      final refBox = SkinObjectData.screenRectToRefBox(quadData.screenRect);
      return FskQuad.fromData(quadData.id, scene, refBox, quadData);
    });
  }

  /////////////////////////////////////////////////////////////////////////////
  // Public API
  /////////////////////////////////////////////////////////////////////////////
  bool get premultiplyAlpha => _premultiplyAlpha;

  set premultiplyAlpha(bool value) {
    _premultiplyAlpha = value;
    _renderer.premultiplyAlpha = value;
  }

  @override
  void rebuildPipelineIfNeeded() {
    _renderer.rebuildPipeline();
  }

  /// Sets a new texture and flags the text for a rebuild.
  void setTexture(String textureId) {
    _renderer.setTexture(FSK().textureManager.getTextureInfo(textureId));
  }

  Color get modulateColor => _modulateColor;
  set modulateColor(Color value) {
    if (_modulateColor != value) {
      _modulateColor = value;
      parentScene.setNeedsUpdate();
    }
  }

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskQuad(
    super.id,
    super.parentScene,
    super.refBox,
    this._textureRect, {
    Color modulateColor = Colors.white,
    String? textureId,
    FskShaderMaterial? shaderMaterial,
  }) {
    _init(
      modulateColor: modulateColor,
      textureId: textureId,
      shaderMaterial: shaderMaterial,
    );
  }

  FskQuad.fromData(
    super.id,
    super.parentScene,
    super.refBox,
    SkinQuadData quadData,
  ) : _textureRect = quadData.textureRect {
    _init(
      modulateColor: parseHexColor(quadData.modulateColor, defaultColor: Colors.white),
      textureId: quadData.texture,
    );
    premultiplyAlpha = quadData.premultiplyAlpha;
    visible = quadData.visible;
  }

  void _init({
    Color modulateColor = Colors.white,
    String? textureId,
    FskShaderMaterial? shaderMaterial,
  }) {
    setRenderer(_renderer);
    setTexture(textureId ?? FSK().textureManager.transparentTextureId);

    if (shaderMaterial != null) {
      this.shaderMaterial = shaderMaterial;
    }

    // Trigger the setter
    this.modulateColor = modulateColor;

    setDepthState(
      depthTestEnabled: false,
      depthWriteEnabled: false,
      depthCompareOperation: gpu.CompareFunction.always,
    );

    _updateQuad();
  }

  static ReferenceBox createRefBox(Size size) {
    return ReferenceBox(
      vm.Vector3(-size.width / 2, -size.height / 2, 0.0),
      vm.Vector3(size.width, 0, 0),
      vm.Vector3(0, size.height, 0),
      vm.Vector3(0, 0, 1),
    );
  }

  static ReferenceBox createRefBoxAtCorner(Size size) {
    return ReferenceBox(
      vm.Vector3.zero(),
      vm.Vector3(size.width, 0, 0),
      vm.Vector3(0, size.height, 0),
      vm.Vector3(0, 0, 1),
    );
  }

  /// Creates a centered 2D quad of the specified [size] at [z] depth.
  factory FskQuad.centered(
    String id,
    FskSceneBase scene,
    Size size, {
    Color modulateColor = Colors.white,
    String? textureId,
    FskShaderMaterial? shaderMaterial,
  }) {
    return FskQuad(
      id,
      scene,
      createRefBox(size),
      const Rect.fromLTWH(0, 0, 1, 1),
      modulateColor: modulateColor,
      textureId: textureId,
      shaderMaterial: shaderMaterial,
    );
  }

  factory FskQuad.atPoint(
    String id,
    vm.Vector3 location,
    Size size,
    FskSceneBase scene, {
    Color modulateColor = Colors.white,
    String? textureId,
    FskShaderMaterial? shaderMaterial,
  }) {
    final quad = FskQuad(
      id,
      scene,
      createRefBox(size),
      const Rect.fromLTWH(0, 0, 1, 1),
      modulateColor: modulateColor,
      textureId: textureId,
      shaderMaterial: shaderMaterial,
    );
    quad.position = location;
    return quad;
  }

  void _updateQuad() {
    vm.Vector2 blc = vm.Vector2(0, 0);
    vm.Vector2 trc = vm.Vector2(refBox.xVector.length, refBox.yVector.length);
    _quad = refBox.calcQuadFrom2DVectors(blc, trc);
  }

  /// Rebuilds the vertex buffer object
  @override
  void doRebuild() {
    _updateQuad();
    _renderer.setFromQuads([_quad], [_textureRect]);
  }

  @override
  vm.Aabb3 getAabb() {
    final vm.Aabb3 bounds = vm.Aabb3.minMax(
      vm.Vector3.copy(_quad.point0),
      vm.Vector3.copy(_quad.point0),
    );
    bounds.hullPoint(_quad.point1);
    bounds.hullPoint(_quad.point2);
    bounds.hullPoint(_quad.point3);
    return bounds;
  }

  @override
  List<FskHitDetails> doHitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    // 1. Ray-Plane intersection
    final vm.Vector3? hit = rayIntersect(ray);
    if (hit == null) return [];

    // 2. Check if hit point is inside quad
    final vm.Vector3 localHit = refBox.calcLocalCoordinates(hit);

    if (localHit.x >= 0 &&
        localHit.x <= refBox.xVector.length &&
        localHit.y >= 0 &&
        localHit.y <= refBox.yVector.length) {
      return [
        FskHitDetails(
          hitObject: this,
          hitPoint: hit,
          localHitPoint: localHit,
          distance: ray.origin.distanceTo(hit),
          normal: _quad.getSurfaceNormal(),
          hitData: null,
        )
      ];
    }

    return [];
  }

  vm.Vector3? rayIntersect(vm.Ray ray) {
     // ReferenceBox or Quad doesn't have a direct plane hit test?
     // Actually ReferenceBox has rayIntersect.
     return refBox.rayIntersect(ray);
  }
}
