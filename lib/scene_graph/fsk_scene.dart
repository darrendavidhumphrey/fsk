import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDownEvent, PointerMoveEvent, PointerUpEvent, PointerCancelEvent, PointerSignalEvent, PointerHoverEvent, PointerEnterEvent, PointerExitEvent;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

import 'fsk_scene_base.dart';
import '../fsk_singleton.dart';
import '../geometry/mesh_hit_tester.dart';
import '../gpu/fsk_render_target.dart';
import '../skins/skin_scene_parser.dart';
import '../skins/skin_scene_builder.dart';
import 'fsk_group.dart';
import 'fsk_scene_object.dart';

class FskScene extends FskSceneBase with FskSceneLayerDispatcherMixin {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  Size skinSize = Size.zero;

  bool useBoxFitLayout = true;
  bool autoClear = true;
  String? _pendingSkinPath;

  FskScene({super.navigationDelegate, super.clearColor}) {
    isReady = false;
  }

  FskScene.fromSkinFile(String skinPath,
      {super.navigationDelegate, super.clearColor}) {
    isReady = false;
    _pendingSkinPath = skinPath;
  }

  @override
  Future<void> onInit() async {
    await super.onInit();
    if (_pendingSkinPath != null) {
      await loadSkin(_pendingSkinPath!);
      _pendingSkinPath = null;
    }
  }

  // Replaces a top level node
  void addOrReplaceNode(FskSceneObject? oldNode, FskSceneObject newNode) {
    if (oldNode == newNode) {
      return;
    }
    if (oldNode == null) {
      addNode(newNode);
    }
    for (int i=0; i < rootNodes.length; i++) {
       if (rootNodes[i] == oldNode) {
         rootNodes[i] = newNode;
         newNode.rebuildGeometry();
         setNeedsUpdate();
       }
    }
  }

  void addNode(FskSceneObject node) {
    if (FskGroup.enableDuplicateIdCheck && nodeMap.containsKey(node.id)) {
      logWarning('Duplicate node ID "${node.id}" added to FskScene.');
    }
    rootNodes.add(node);
    nodeMap[node.id] = node;
  }

  void addNodes(List<FskSceneObject> nodes) {
    for (var node in nodes) {
      addNode(node);
    }
  }

  void addLayer(FskSceneBase layer) {
    layers.add(layer);
    layer.init();
    layer.addListener(() {
      setNeedsUpdate();
    });
    layer.cursorNotifier.addListener(() {
      setCursor(layer.cursorNotifier.value);
    });
    setNeedsUpdate();
  }

  void clearNodes() {
    for (var node in rootNodes) {
      node.dispose();
    }
    rootNodes.clear();
    nodeMap.clear();
    setNeedsUpdate();
  }

  /// Performs a hit test traversal of the scene graph.
  @override
  List<FskHitDetails> hitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    final List<FskHitDetails> results = [];

    for (final node in rootNodes) {
      final hits = node.hitTest(ray, mode: mode);
      if (hits.isNotEmpty) {
        if (mode == FskHitTestMode.first) {
          return hits;
        }
        results.addAll(hits);
      }
    }

    if (mode == FskHitTestMode.closest && results.length > 1) {
      results.sort((a, b) => a.distance.compareTo(b.distance));
      return [results.first];
    }

    if (mode == FskHitTestMode.all) {
      results.sort((a, b) => a.distance.compareTo(b.distance));
    }

    return results;
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients, [gpu.RenderPass? parentRenderPass, bool isLast = true]) {
    if (!isReady) return;

    try {
      super.drawScene(commandBuffer, renderTarget, transients, parentRenderPass, isLast);

      // 1. Calculate the layout matrix.
      vm.Matrix4 layoutMatrix = vm.Matrix4.identity();
      if (useBoxFitLayout) {
        vm.Matrix4? boxFitMatrix =
            navigationDelegate?.createBoxFitMatrix(skinSize);
        if (boxFitMatrix != null) {
          layoutMatrix = boxFitMatrix * layoutMatrix;
        }
        layoutMatrix.translateByVector3(vm.Vector3(-skinSize.width / 2, -skinSize.height / 2, 0));
      }

      // 2. Combine layout with the current view matrix (mvMatrix).
      final vm.Matrix4 finalMvMatrix = layoutMatrix * mvMatrix;

      // 3. RenderPass Management
      gpu.RenderPass renderPass;
      if (parentRenderPass != null) {
        renderPass = parentRenderPass;
      } else {
        // We are the root. Clear if autoClear is true. 
        // We NEVER resolve here anymore; the GPURenderWidget handles final resolve.
        final gpu.RenderTarget target = autoClear 
            ? renderTarget.clearTarget 
            : renderTarget.loadTarget;

        renderPass = commandBuffer.createRenderPass(target);
        hardResetPipelineState(renderPass);
      }

      // 4. Draw geometry
      for (final node in rootNodes) {
        if (node is FskRenderableObject && node.visible) {
          node.draw(renderPass, transients, pMatrix, finalMvMatrix, viewportSize);
        }
      }

      // 5. Draw sub-layers
      for (int i = 0; i < layers.length; i++) {
        // Sub-layers share our pass if they can
        layers[i].drawScene(commandBuffer, renderTarget, transients, renderPass, isLast);
      }
    } catch (e, s) {
      logError("CRITICAL Error in FskScene.drawScene: $e\n$s");
    }
  }

  @override
  void rebuildGeometry() {
    for (var node in rootNodes) {
      node.rebuildGeometry();
    }
    for (var layer in layers) {
      layer.rebuildGeometry();
    }
  }

  @override
  void dispose() {
    clearNodes();
    super.dispose();
  }

  T? findNode<T>(String id) {
    var node = nodeMap[id];
    if (node is T) return node as T;
    return null;
  }

  // Override this method to invoke code when the skin has completed loading
  Future<void> onSkinReady() async {}

  Future<void> loadSkin(String skinPath) async {
    try {
      var frameData = await SkinSceneParser.parseFromAssets(skinPath);
      if (frameData != null) {
        var builder = SkinSceneBuilder(this, frameData);
        skinSize = frameData.skinSize;
        final success = await builder.buildScene();
        if (success) {
          await onSkinReady();
          isReady = true;
          notifyListeners();
        }
      }
    } catch (e, stackTrace) {
      logError("Error skin XML '$skinPath': $e");
      logError(stackTrace.toString());
    }
  }

  void dumpSceneGraph() {
    for (var node in rootNodes) {
      node.dumpSceneGraph();
    }
  }
}

/// A mixin that dispatches input events to the scene's [layers].
mixin FskSceneLayerDispatcherMixin on FskSceneBase {
  final List<FskSceneBase> layers = [];

  /// Map of pointer IDs to the overlay that currently "owns" them.
  /// If the value is null, the main scene owns the pointer.
  final Map<int, FskSceneBase?> _pointerCaptures = {};

  Size get logicalSize => Size(viewportSize.width / FSK.devicePixelRatio,
      viewportSize.height / FSK.devicePixelRatio);

  @override
  bool onPointerDown(PointerDownEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity()));

        if (layer.onPointerDown(transformedEvent)) {
          _pointerCaptures[event.pointer] = layer;
          return true;
        }
      }
    }
    _pointerCaptures[event.pointer] = null;
    return super.onPointerDown(event);
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        return layer.onPointerMove(event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity())));
      }
    }
    return super.onPointerMove(event);
  }

  @override
  bool onPointerUp(PointerUpEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      _pointerCaptures.remove(event.pointer);
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        return layer.onPointerUp(event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity())));
      }
    }
    return super.onPointerUp(event);
  }

  @override
  bool onPointerCancel(PointerCancelEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      _pointerCaptures.remove(event.pointer);
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        return layer.onPointerCancel(event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity())));
      }
    }
    return super.onPointerCancel(event);
  }

  @override
  bool onPointerSignal(PointerSignalEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity())) as PointerSignalEvent;

        if (layer.onPointerSignal(transformedEvent)) return true;
      }
    }

    return super.onPointerSignal(event);
  }

  @override
  bool onPointerHover(PointerHoverEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity()));
        if (layer.onPointerHover(transformedEvent)) return true;
      }
    }
    return super.onPointerHover(event);
  }

  @override
  bool onPointerEnter(PointerEnterEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity()));
        if (layer.onPointerEnter(transformedEvent)) return true;
      }
    }
    return super.onPointerEnter(event);
  }

  @override
  bool onPointerExit(PointerExitEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        final transformedEvent = event.transformed(
            vm64.Matrix4.translationValues(-origin.dx, -origin.dy, 0) *
                (event.transform ?? vm64.Matrix4.identity()));
        if (layer.onPointerExit(transformedEvent)) return true;
      }
    }
    return super.onPointerExit(event);
  }

  @override
  bool onScaleStart(ScaleStartDetails details) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(details.localFocalPoint, logicalSize)) {
        final transformedDetails = ScaleStartDetails(
          focalPoint: details.focalPoint,
          localFocalPoint:
              layer.screenToViewport(details.localFocalPoint, logicalSize),
          pointerCount: details.pointerCount,
        );
        if (layer.onScaleStart(transformedDetails)) return true;
      }
    }
    return super.onScaleStart(details);
  }

  @override
  bool onScaleUpdate(ScaleUpdateDetails details) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(details.localFocalPoint, logicalSize)) {
        final transformedDetails = ScaleUpdateDetails(
          focalPoint: details.focalPoint,
          localFocalPoint:
              layer.screenToViewport(details.localFocalPoint, logicalSize),
          scale: details.scale,
          horizontalScale: details.horizontalScale,
          verticalScale: details.verticalScale,
          rotation: details.rotation,
          pointerCount: details.pointerCount,
          focalPointDelta: details.focalPointDelta,
        );
        if (layer.onScaleUpdate(transformedDetails)) return true;
      }
    }
    return super.onScaleUpdate(details);
  }

  @override
  bool onScaleEnd(ScaleEndDetails details) {
    bool handled = false;
    for (var layer in layers) {
      if (layer.onScaleEnd(details)) handled = true;
    }
    return super.onScaleEnd(details) || handled;
  }
}
