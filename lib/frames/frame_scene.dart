import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk.dart';
import 'frame_scene_builder.dart';

class FskFrameScene extends FskScene {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  Size frameSize = Size.zero;

  bool useBoxFitLayout = true;
  String? _pendingSkinPath;

  FskFrameScene({super.navigationDelegate}) {
    isReady = false;
  }

  FskFrameScene.fromSkinFile(String skinPath, {super.navigationDelegate}) {
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
      logWarning('Duplicate node ID "${node.id}" added to FskFrameScene.');
    }
    rootNodes.add(node);
    nodeMap[node.id] = node;
  }

  void addNodes(List<FskSceneObject> nodes) {
    for (var node in nodes) {
      addNode(node);
    }
  }

  void clearNodes() {
    rootNodes.clear();
    nodeMap.clear();
    setNeedsUpdate();
  }

  @override
  void drawScene(gpu.CommandBuffer commandBuffer, FskRenderTarget renderTarget, gpu.HostBuffer transients) {
    if (!isReady) return;

    try {
      super.drawScene(commandBuffer, renderTarget, transients);

      Matrix4 layoutMatrix = Matrix4.identity();
      if (useBoxFitLayout) {
        Matrix4? boxFitMatrix = navigationDelegate?.createBoxFitMatrix(frameSize);

        if (boxFitMatrix != null) {
          layoutMatrix = boxFitMatrix * layoutMatrix;
        }

        // Center object in view by translating content origin to its center
        layoutMatrix.translateByVector3(
          Vector3(
            -frameSize.width / 2,
            -frameSize.height / 2,
            0,
          ),
        );
      }

      final Matrix4 finalMvMatrix = layoutMatrix * mvMatrix;

      bool hasCleared = false;

      for (var node in rootNodes) {
        if (node is FskRenderableObject && node.visible) {
          // Force hardware state reset between top-level nodes by creating a new RenderPass.
          // The first visible node clears the buffer; subsequent nodes load it.
          final renderPass = commandBuffer.createRenderPass(
            hasCleared ? renderTarget.loadTarget : renderTarget.renderTarget,
          );
          hasCleared = true;

          super.setupScissor(renderPass);

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
      }
    } catch (e, s) {
      logError("CRITICAL Error in FskFrameScene.drawScene: $e\n$s");
    }
  }

  @override
  void rebuildGeometry() {
    for (var node in rootNodes) {
      node.rebuildGeometry();
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
      var frameData = await FrameSceneParser.parseFromAssets(skinPath);
      if (frameData != null) {
        var builder = FrameSceneBuilder(this, frameData);
        frameSize = frameData.frameSize;
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
