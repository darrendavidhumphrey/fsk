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

  FskFrameScene({super.navigationDelegate}) {
    isReady = false;
  }

  FskFrameScene.fromSkinFile(String skinPath, {super.navigationDelegate}) {
    loadSkin(skinPath);
  }

  void addNode(FskSceneObject node) {
    rootNodes.add(node);
    nodeMap[node.id] = node;
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (!isReady) return;

    super.setupScissor(renderPass);

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

    for (var node in rootNodes) {
      if (node is FskRenderableObject) {
        node.draw(
            renderPass,
            transients,
            pMatrix.clone(),
            finalMvMatrix.clone(),
            viewportSize);
      }
    }
  }

  @override
  void rebuildGeometry() {
    for (var node in rootNodes) {
      node.rebuildGeometry();
    }
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
        isReady = await builder.buildScene();
        if (isReady) await onSkinReady();
      }
    } catch (e, stackTrace) {
      logError("Error skin XML '$skinPath': $e");
      logError(stackTrace.toString());
    }
  }
}
