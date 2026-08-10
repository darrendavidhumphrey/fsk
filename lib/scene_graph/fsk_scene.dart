import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:fsk/fsk.dart';
import '../skins/skin_scene_builder.dart';

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
      gpu.HostBuffer transients) {
    if (!isReady) return;

    try {
      super.drawScene(commandBuffer, renderTarget, transients);

      // 1. Calculate the layout matrix (e.g. for BoxFit logic).
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

      // 2. Combine layout with the current view matrix (mvMatrix).
      final vm.Matrix4 finalMvMatrix = layoutMatrix * mvMatrix;

      // 3. Create a single RenderPass for all root nodes.
      final renderPass = commandBuffer.createRenderPass(
        autoClear ? renderTarget.renderTarget : renderTarget.loadTarget,
      );

      setupScissor(renderPass);

      for (final node in rootNodes) {
        if (node is FskRenderableObject && node.visible) {
          node.draw(
            renderPass,
            transients,
            pMatrix,
            finalMvMatrix,
            viewportSize,
          );
        }
      }

      // 4. Draw overlays (each manages its own passes for depth/scissor isolation)
      for (final layer in layers) {
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
