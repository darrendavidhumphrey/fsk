import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show PointerDownEvent, PointerMoveEvent, PointerUpEvent, PointerCancelEvent, PointerSignalEvent, PointerHoverEvent, PointerEnterEvent, PointerExitEvent;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vector_math/vector_math_64.dart' as vm64;

import '../fsk_singleton.dart';
import '../geometry/geometry_util.dart';
import '../geometry/mesh_hit_tester.dart';
import '../gpu/fsk_render_target.dart';
import '../skins/skin_scene_parser.dart';
import '../skins/skin_scene_builder.dart';

import 'fsk_scene_base.dart';
import 'fsk_group.dart';
import 'fsk_scene_object.dart';
import 'fsk_widget_portal.dart';
import 'fsk_renderer_base.dart';

class FskScene extends FskSceneBase with FskSceneLayerDispatcherMixin {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  Size skinSize = Size.zero;

  bool useBoxFitLayout = true;
  bool autoClear = true;
  String? _pendingSkinPath;

  final List<FskWidgetPortal> widgetPortals = [];

  /// Internal list of widget draw commands collected during traversal.
  final List<FskWidgetDrawCommand> widgetDrawCommands = [];

  void addWidgetPortal(FskWidgetPortal portal) {
    widgetPortals.add(portal);
    notifyListeners();
  }

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

  @override
  vm.Matrix4 getLayoutMatrix() {
    vm.Matrix4 layoutMatrix = vm.Matrix4.identity();
    if (useBoxFitLayout) {
      vm.Matrix4? boxFitMatrix =
          navigationDelegate?.createBoxFitMatrix(skinSize);
      if (boxFitMatrix != null) {
        layoutMatrix = boxFitMatrix * layoutMatrix;
      }
      layoutMatrix.translateByVector3(vm.Vector3(-skinSize.width / 2, -skinSize.height / 2, 0));
    }
    return layoutMatrix;
  }

  /// Performs a hit test traversal of the scene graph.
  @override
  List<FskHitDetails> hitTest(vm.Ray ray,
      {FskHitTestMode mode = FskHitTestMode.closest}) {
    final List<FskHitDetails> results = [];

    final vm.Matrix4 layoutMatrix = getLayoutMatrix();
    final vm.Matrix4 invLayout = vm.Matrix4.copy(layoutMatrix)..invert();
    final vm.Ray localRay = transformRay(ray, invLayout);

    // To find the closest hit across all root nodes, we must gather everything.
    final childMode = (mode == FskHitTestMode.closest) ? FskHitTestMode.all : mode;

    for (final node in rootNodes) {
      final hits = node.hitTest(localRay, mode: childMode);
      if (hits.isNotEmpty) {
        // Transform hits back to world space
        for (var i = 0; i < hits.length; i++) {
          final hit = hits[i];
          final worldHitPoint =
              layoutMatrix.transform3(vm.Vector3.copy(hit.hitPoint));
          final worldNormal =
              layoutMatrix.rotate3(vm.Vector3.copy(hit.normal))..normalize();
          hits[i] = FskHitDetails(
            hitObject: hit.hitObject,
            hitPoint: worldHitPoint,
            localHitPoint: hit.localHitPoint,
            distance: ray.origin.distanceTo(worldHitPoint),
            normal: worldNormal,
            hitData: hit.hitData,
          );
        }
        results.addAll(hits);
      }
    }

    if (results.isEmpty) return [];

    results.sort((a, b) => a.distance.compareTo(b.distance));

    if (mode == FskHitTestMode.first || mode == FskHitTestMode.closest) {
      return [results.first];
    }

    return results;
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients,
      [gpu.RenderPass? parentRenderPass, bool isLast = true]) {
    if (!isReady) return;

    try {
      widgetDrawCommands.clear();
      super.drawScene(
          commandBuffer, renderTarget, transients, parentRenderPass, isLast);

      // 1. Calculate the layout matrix.
      vm.Matrix4 layoutMatrix = getLayoutMatrix();

      // 2. Combine layout with the current view matrix (mvMatrix).
      final vm.Matrix4 finalMvMatrix = layoutMatrix * mvMatrix;

      // 3. RenderPass Management
      gpu.RenderPass renderPass;
      if (parentRenderPass != null) {
        renderPass = parentRenderPass;
      } else {
        // We are the root. Clear if autoClear is true.
        final gpu.RenderTarget target =
            autoClear ? renderTarget.clearTarget : renderTarget.loadTarget;

        renderPass = commandBuffer.createRenderPass(target);
        hardResetPipelineState(renderPass);
      }

      // 4. Draw content
      renderNodes(renderPass, transients, pMatrix, finalMvMatrix, viewportSize);

      // 5. Draw sub-layers
      renderLayers(commandBuffer, renderTarget, transients, renderPass, isLast);

      // 6. Draw collected Flutter widgets in a truly separate pass for maximum isolation.
      // This happens AFTER layers to ensure widgets stay on top.
      renderWidgets(commandBuffer, renderTarget, transients);
    } catch (e, s) {
      logError("CRITICAL Error in FskScene.drawScene: $e\n$s");
    }
  }

  /// Draws all root nodes into the provided [renderPass].
  @protected
  void renderNodes(gpu.RenderPass renderPass, gpu.HostBuffer transients,
      vm.Matrix4 pMatrix, vm.Matrix4 mvMatrix, Size viewportSize) {
    for (final node in rootNodes) {
      if (node is FskRenderableObject && node.visible) {
        try {
          node.draw(renderPass, transients, pMatrix, mvMatrix, viewportSize);
        } catch (e, s) {
          logError("Error drawing node ${node.id}: $e\n$s");
        }
      }
    }
  }

  /// Draws all sub-layers into the provided [renderPass].
  @protected
  void renderLayers(
      gpu.CommandBuffer commandBuffer,
      FskRenderTarget renderTarget,
      gpu.HostBuffer transients,
      gpu.RenderPass renderPass,
      bool isLast) {
    for (int i = 0; i < layers.length; i++) {
      try {
        layers[i].drawScene(
            commandBuffer, renderTarget, transients, renderPass, isLast);
      } catch (e, s) {
        logError("Error drawing layer $i: $e\n$s");
      }
    }
  }

  /// Draws all collected widget commands in a separate pass.
  @protected
  void renderWidgets(gpu.CommandBuffer commandBuffer,
      FskRenderTarget renderTarget, gpu.HostBuffer transients) {
    if (widgetDrawCommands.isNotEmpty) {
      final widgetPass = commandBuffer.createRenderPass(renderTarget.loadTarget);
      hardResetPipelineState(widgetPass);

      for (final cmd in widgetDrawCommands) {
        try {
          // Ensure uniforms are updated with the object's current state.
          cmd.object.updateUniforms(cmd.renderer.uniforms!);

          cmd.renderer.draw(widgetPass, transients, cmd.pMatrix, cmd.mvMatrix,
              cmd.viewportSize);
        } catch (e, s) {
          logError("Error drawing widget node: $e\n$s");
        }
      }
    }
  }

  @override
  void updateAnimations(DateTime now) {
    super.updateAnimations(now);
    for (var layer in layers) {
      layer.updateAnimations(now);
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

  @override
  KeyEventResult onKeyEvent(KeyEvent event) {
    // Forward key events to the navigation delegate which forwards to behaviors
    return navigationDelegate?.onKeyEvent(event) ?? KeyEventResult.ignored;
  }

  /// Internal registration for widget draw commands.
  void registerWidgetDraw(FskRenderableObject object, FskRendererBase renderer, vm.Matrix4 pMatrix, vm.Matrix4 mvMatrix, Size viewportSize) {
    widgetDrawCommands.add(FskWidgetDrawCommand(
      object: object,
      renderer: renderer,
      pMatrix: pMatrix,
      mvMatrix: mvMatrix,
      viewportSize: viewportSize,
    ));
  }
}

class FskWidgetDrawCommand {
  final FskRenderableObject object;
  final FskRendererBase renderer;
  final vm.Matrix4 pMatrix;
  final vm.Matrix4 mvMatrix;
  final Size viewportSize;

  FskWidgetDrawCommand({
    required this.object,
    required this.renderer,
    required this.pMatrix,
    required this.mvMatrix,
    required this.viewportSize,
  });
}

/// A mixin that dispatches input events to the scene's [layers].
mixin FskSceneLayerDispatcherMixin on FskSceneBase {
  final List<FskSceneBase> layers = [];

  /// Map of pointer IDs to the overlay that currently "owns" them.
  /// If the value is null, the main scene owns the pointer.
  final Map<int, FskSceneBase?> _pointerCaptures = {};

  /// Map of pointer IDs to the scene object that currently "owns" them.
  final Map<int, FskRenderableObject?> _objectCaptures = {};

  /// The scene object currently under the mouse cursor.
  FskRenderableObject? _currentHoveredObject;

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

    // Hit test against the 3D scene
    final ray = navigationDelegate?.getWorldRay(event.localPosition);
    if (ray != null) {
      final hits = hitTest(ray, mode: FskHitTestMode.closest);
      if (hits.isNotEmpty) {
        final hit = hits.first;
        if (hit.hitObject is FskRenderableObject) {
          final obj = hit.hitObject as FskRenderableObject;
          if (obj.onPointerDown(event, hit)) {
            _objectCaptures[event.pointer] = obj;
            return true;
          }
        }
      }
    }

    _pointerCaptures[event.pointer] = null;
    return super.onPointerDown(event);
  }

  @override
  bool onPointerMove(PointerMoveEvent event) {
    if (_objectCaptures.containsKey(event.pointer)) {
      final obj = _objectCaptures[event.pointer];
      if (obj != null) {
        final ray = navigationDelegate?.getWorldRay(event.localPosition);
        if (ray != null) {
          final hits = obj.hitTest(ray, mode: FskHitTestMode.first);
          if (hits.isNotEmpty) {
            return obj.onPointerMove(event, hits.first);
          }
        }
        return obj.onPointerMove(event, FskHitDetails(hitObject: obj, hitPoint: vm.Vector3.zero(), localHitPoint: vm.Vector3.zero(), distance: 0, normal: vm.Vector3.zero(), hitData: null));
      }
    }

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
    if (_objectCaptures.containsKey(event.pointer)) {
      final obj = _objectCaptures.remove(event.pointer);
      if (obj != null) {
        final ray = navigationDelegate?.getWorldRay(event.localPosition);
        if (ray != null) {
          final hits = obj.hitTest(ray, mode: FskHitTestMode.first);
          if (hits.isNotEmpty) {
            return obj.onPointerUp(event, hits.first);
          }
        }
        return obj.onPointerUp(event, FskHitDetails(hitObject: obj, hitPoint: vm.Vector3.zero(), localHitPoint: vm.Vector3.zero(), distance: 0, normal: vm.Vector3.zero(), hitData: null));
      }
    }

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

    // Hit test against the 3D scene for hover
    final ray = navigationDelegate?.getWorldRay(event.localPosition);
    FskRenderableObject? hitObj;
    FskHitDetails? hitDetails;

    if (ray != null) {
      final hits = hitTest(ray, mode: FskHitTestMode.first);
      if (hits.isNotEmpty && hits.first.hitObject is FskRenderableObject) {
        hitObj = hits.first.hitObject as FskRenderableObject;
        hitDetails = hits.first;
      }
    }

    if (hitObj != _currentHoveredObject) {
      _currentHoveredObject?.onPointerExit(event);
      _currentHoveredObject = hitObj;
      _currentHoveredObject?.onPointerEnter(event, hitDetails);
    }

    if (hitObj != null && hitDetails != null) {
      return hitObj.onPointerHover(event, hitDetails);
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
