import 'dart:ui';
import 'package:fsk/fsk.dart';
import 'package:fsk/scene_graph/fsk_renderer_base.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:flutter_gpu/gpu.dart' as gpu;

abstract class FskSceneObject with LoggableClass {
  final String id;
  final FskSceneBase parentScene;

  FskSceneObject(this.id, this.parentScene);

  bool needsRebuild = true;
  void setNeedsRebuild() {
    needsRebuild = true;
  }

  void rebuildGeometry() {
    rebuildGeometryIfNeeded();
    rebuildPipelineIfNeeded();
  }

  void rebuildGeometryIfNeeded() {
    if (!needsRebuild) return;
    doRebuild();
    needsRebuild = false;
  }

  void doRebuild() {}
  void rebuildPipelineIfNeeded();

  /// Performs a hit test against this object.
  List<FskHitDetails> hitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    return [];
  }

  /// Recursively searches for a node with the given [path] (dotted notation) and type [T].
  T? findNode<T>(String path) {
    return findNodeRecursive<T>(path.split('.'));
  }

  /// Internal recursive helper for dotted path searching.
  T? findNodeRecursive<T>(List<String> parts) {
    if (parts.isEmpty) return null;
    if (id == parts[0]) {
      if (parts.length == 1) {
        return (this is T) ? this as T : null;
      }
    }
    return null;
  }
}

abstract class FskRenderableObject extends FskSceneObject {
  final FskTransformable transformable = FskTransformable();
  bool visible = true;

  FskRenderableObject(super.id, super.parentScene);
  FskRendererBase? _renderer;

  FskRendererBase get renderer => _renderer!;

  BaseUniforms? get uniforms => _renderer?.uniforms;
  set uniforms(BaseUniforms? value) {
    if (_renderer == null) return;
    if (_renderer!.uniforms == value) return;
    _renderer!.uniforms?.removeListener(_onRendererChanged);
    _renderer!.uniforms = value;
    _renderer!.uniforms?.addListener(_onRendererChanged);

    // Only trigger a rebuild if we're not currently in the middle of a draw/rebuild cycle
    if (!needsRebuild) {
      parentScene.setNeedsUpdate();
    }
  }

  void draw(gpu.RenderPass renderPass, gpu.HostBuffer transients,
      vm.Matrix4 pMatrix, vm.Matrix4 mvMatrix, Size viewportSize) {
    if (!visible) return;

    vm.Matrix4 finalMvMatrix = mvMatrix.clone();
    if (transformable.isTransformed()) {
      finalMvMatrix.multiply(transformable.getTransform());
    }

    _renderer?.draw(
        renderPass, transients, pMatrix, finalMvMatrix, viewportSize);
  }

  @override
  List<FskHitDetails> hitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    if (!visible) return [];

    vm.Ray localRay = ray;
    if (transformable.isTransformed()) {
      final vm.Matrix4 worldToLocal =
          vm.Matrix4.copy(transformable.getTransform())..invert();
      localRay = transformRay(ray, worldToLocal);
    }

    return doHitTest(localRay, mode: mode);
  }

  /// Internal hit test implementation for subclasses.
  /// The [ray] is already in local coordinate space.
  List<FskHitDetails> doHitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    return [];
  }

  void setRenderer(FskRendererBase newRenderer) {
    _renderer?.removeListener(_onRendererChanged);
    _renderer?.uniforms?.removeListener(_onRendererChanged);
    _renderer = newRenderer;
    _renderer?.addListener(_onRendererChanged);
    _renderer?.uniforms?.addListener(_onRendererChanged);
  }

  void _onRendererChanged() {
    parentScene.setNeedsUpdate();
  }

  set shaderMaterial(FskShaderMaterial value) {
    if (_renderer == null) return;
    _renderer!.uniforms?.removeListener(_onRendererChanged);
    _renderer!.shaderMaterial = value;
    _renderer!.rebuildPipeline();
    _renderer!.uniforms?.addListener(_onRendererChanged);
    parentScene.setNeedsUpdate();
  }
}

abstract class Fsk2DRenderableObject extends FskRenderableObject {
  Fsk2DRenderableObject(super.id, super.parentScene, this.refBox);
  final ReferenceBox refBox;
}
