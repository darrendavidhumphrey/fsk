import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk.dart';
import 'frame_scene_builder.dart';

class FskFrameScene extends FskScene {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  Size frameSize = Size.zero;

  FskFrameScene({super.navigationDelegate}) {
    isReady = false;
  }

  FskFrameScene.fromSkinFile(String skinPath, {super.navigationDelegate}) {
    loadSkin(skinPath);
  }

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (!isReady) {
      return;
    }

    super.setupScissor(renderPass);

    Matrix4 finalMvMatrix = mvMatrix.clone();

    Matrix4? boxFitMatrix = navigationDelegate?.createBoxFitMatrix(frameSize);

    if (boxFitMatrix != null) {
      finalMvMatrix = finalMvMatrix * boxFitMatrix;
    }

    // Center object in view
    finalMvMatrix.translateByVector3(
      Vector3(
        -frameSize.width / 2,
        -frameSize.height / 2,
        0,
      ),
    );

    for (var node in rootNodes) {
      if (node is FskRenderableObject) {
        node.draw(
            renderPass, transients, pMatrix.clone(), finalMvMatrix.clone());
      }
    }
  }

  @override
  void rebuildGeometry() {
    for (var node in rootNodes) {
      node.rebuildGeometry();
    }
  }

  // Generic findNode function
  // NOTE: Assumes a unique ID for each node, not dotted notation
  FskSceneObject? findNode(String id) => nodeMap[id];

  // Type safe findNode function
  T? findNodeByType<T>(String id) {
    var node = nodeMap[id];

    if (node is T) {
      return node as T;
    }

    return null;
  }

  Future<void> loadSkin(String skinPath) async {
    try {
      var frameData = await FrameSceneParser.parseFromAssets(skinPath);
      if (frameData != null) {
        var builder = FrameSceneBuilder(this, frameData);
        frameSize = frameData.frameSize;

        isReady = await builder.buildScene();
      }

    } catch (e, stackTrace) {
      logError("Error skin XML '$skinPath': $e");
      logError("StackTrace: $stackTrace");
    }
  }
}
