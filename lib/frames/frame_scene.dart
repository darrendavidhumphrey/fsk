import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk.dart';
import 'frame_scene_builder.dart';

class FskFrameScene extends FskScene {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  Size frameSize = Size.zero;

  bool use2DLayout = true;

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
    if (use2DLayout) {
      Matrix4? boxFit = navigationDelegate?.createBoxFitMatrix(frameSize);
      if (boxFit != null) layoutMatrix = boxFit * layoutMatrix;

      layoutMatrix.translateByVector3(
        Vector3(
          -frameSize.width / 2,
          -frameSize.height / 2,
          0.0,
        ),
      );
    }

    final Matrix4 stageMvMatrix = layoutMatrix.clone()..multiply(mvMatrix);

    for (var node in rootNodes) {
      _recursiveDraw(node, renderPass, transients, pMatrix.clone(), stageMvMatrix.clone());
    }
  }

  void _recursiveDraw(FskSceneObject node, gpu.RenderPass renderPass, gpu.HostBuffer transients, Matrix4 pMatrix, Matrix4 mvMatrix) {
    if (node is FskRenderableObject) {
      node.draw(renderPass, transients, pMatrix, mvMatrix, viewportSize);
    }
    
    if (node is FskGroup) {
      // Groups already handle recursive drawing of their children in their draw method
      // However, we want to ensure the top-level mvMatrix is applied correctly
    }
  }

  @override
  void rebuildGeometry() {
    for (var node in rootNodes) {
      node.rebuildGeometry();
    }
  }

  T? findNode<T>(String id) {
    final node = nodeMap[id];
    if (node is T) return node as T;
    return null;
  }

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
