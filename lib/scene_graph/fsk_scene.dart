import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/gestures.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import '../fsk.dart';
import '../skins/skin_scene_builder.dart';

class FskScene extends FskSceneBase {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  final List<ScreenSpaceOverlay> layers = [];
  Size skinSize = Size.zero;

  bool useBoxFitLayout = true;
  bool autoClear = true;
  String? _pendingSkinPath;

  /// Map of pointer IDs to the overlay that currently "owns" them.
  /// If the value is null, the main scene owns the pointer.
  final Map<int, ScreenSpaceOverlay?> _pointerCaptures = {};

  FskScene({super.navigationDelegate, super.clearColor}) {
    isReady = false;
  }

  FskScene.fromSkinFile(String skinPath, {super.navigationDelegate,super.clearColor}) {
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

  void addLayer(ScreenSpaceOverlay layer) {
    layers.add(layer);
    layer.init();
    setNeedsUpdate();
  }

  void clearNodes() {
    rootNodes.clear();
    nodeMap.clear();
    setNeedsUpdate();
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget,
      gpu.HostBuffer transients) {
    if (!isReady) return;

    try {
      super.drawScene(commandBuffer, renderTarget, transients);

      // Calculate the layout matrix (e.g. for BoxFit logic).
      vm.Matrix4 layoutMatrix = vm.Matrix4.identity();
      if (useBoxFitLayout) {
        vm.Matrix4? boxFitMatrix =
            navigationDelegate?.createBoxFitMatrix(skinSize);

        if (boxFitMatrix != null) {
          layoutMatrix = boxFitMatrix * layoutMatrix;
        }

        // Center object in view by translating content origin to its center
        layoutMatrix.translateByVector3(
          vm.Vector3(
            -skinSize.width / 2,
            -skinSize.height / 2,
            0,
          ),
        );
      }

      // 3. Combine layout with the current view matrix (mvMatrix).
      final vm.Matrix4 finalMvMatrix = layoutMatrix * mvMatrix;

      bool hasCleared = !autoClear;

      for (var node in rootNodes) {
        if (node is FskRenderableObject && node.visible) {
          // Force hardware state reset between top-level nodes by creating a new RenderPass.
          // The first visible node clears the buffer; subsequent nodes load it.
          final renderPass = commandBuffer.createRenderPass(
            hasCleared ? renderTarget.loadTarget : renderTarget.renderTarget,
          );
          hasCleared = true;

          setupScissor(renderPass);

          node.draw(
            renderPass,
            transients,
            pMatrix,
            finalMvMatrix,
            viewportSize,
          );
        }
      }

      // Ensure the buffer is cleared at least once, even if no nodes were visible.
      if (!hasCleared) {
        commandBuffer.createRenderPass(renderTarget.renderTarget);
        hasCleared = true;
      }

      // Draw overlays
      for (var layer in layers) {
        layer.drawScene(commandBuffer, renderTarget, transients);
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
  }

  Size get logicalSize => Size(viewportSize.width / FSK.devicePixelRatio,
      viewportSize.height / FSK.devicePixelRatio);

  @override
  void onPointerDown(PointerDownEvent event) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        _pointerCaptures[event.pointer] = layer;
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        layer.onPointerDown(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0)));
        return;
      }
    }
    _pointerCaptures[event.pointer] = null;
    super.onPointerDown(event);
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        layer.onPointerMove(event.transformed(
           Matrix4.translationValues(-origin.dx, -origin.dy, 0)));
        return;
      }
    } else {
      // If we don't have a capture, but this is a move event without a down 
      // (like mouse hover), we can still do a hit test for signals.
      // But for rotation drags, we should rely on the capture.
    }
    super.onPointerMove(event);
  }

  @override
  void onPointerUp(PointerUpEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      _pointerCaptures.remove(event.pointer);
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        layer.onPointerUp(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0)));
        return;
      }
    }
    super.onPointerUp(event);
  }

  @override
  void onPointerCancel(PointerCancelEvent event) {
    if (_pointerCaptures.containsKey(event.pointer)) {
      final layer = _pointerCaptures[event.pointer];
      _pointerCaptures.remove(event.pointer);
      if (layer != null) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        layer.onPointerCancel(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0)));
        return;
      }
    }
    super.onPointerCancel(event);
  }

  @override
  void onPointerSignal(PointerSignalEvent event) {
    // Pointer signals (like scroll) don't have a 'down' event to capture.
    // We hit test these on the fly.
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(event.localPosition, logicalSize)) {
        final origin = event.localPosition -
            layer.screenToViewport(event.localPosition, logicalSize);
        layer.onPointerSignal(event.transformed(
            Matrix4.translationValues(-origin.dx, -origin.dy, 0)) as PointerSignalEvent);
        return;
      }
    }
    super.onPointerSignal(event);
  }

  @override
  void onScaleStart(ScaleStartDetails details) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(details.localFocalPoint, logicalSize)) {
        layer.onScaleStart(ScaleStartDetails(
          focalPoint: details.focalPoint,
          localFocalPoint:
              layer.screenToViewport(details.localFocalPoint, logicalSize),
          pointerCount: details.pointerCount,
        ));
        return;
      }
    }
    super.onScaleStart(details);
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails details) {
    for (var layer in layers.reversed) {
      if (layer.interceptInput &&
          layer.isPointInViewport(details.localFocalPoint, logicalSize)) {
        layer.onScaleUpdate(ScaleUpdateDetails(
          focalPoint: details.focalPoint,
          localFocalPoint:
              layer.screenToViewport(details.localFocalPoint, logicalSize),
          scale: details.scale,
          horizontalScale: details.horizontalScale,
          verticalScale: details.verticalScale,
          rotation: details.rotation,
          pointerCount: details.pointerCount,
          focalPointDelta: details.focalPointDelta,
        ));
        return;
      }
    }
    super.onScaleUpdate(details);
  }

  @override
  void onScaleEnd(ScaleEndDetails details) {
    super.onScaleEnd(details);
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event) {
    return super.onKeyEvent(event);
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
}
