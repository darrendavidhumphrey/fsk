import 'dart:ui';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart';
import '../fsk.dart';
import 'frame_scene_builder.dart';

class FskFrameScene extends FskScene {
  final List<FskSceneObject> rootNodes = [];
  final Map<String, FskSceneObject> nodeMap = {};
  Size frameSize = Size.zero;

  /// If true, applies 2D box-fit and centering logic.
  /// Set to false for 3D scenes using the graph for object management.
  bool use2DLayout = true;

  FskFrameScene({super.navigationDelegate}) {
    isReady = false;
  }

  FskFrameScene.fromSkinFile(String skinPath, {super.navigationDelegate}) {
    loadSkin(skinPath);
  }

  /// Adds a node to the scene graph
  void addNode(FskSceneObject node) {
    rootNodes.add(node);
    nodeMap[node.id] = node;
  }

  /// Optional callback to fire when skin loads successfully
  Future<void> onSkinReady() async {}

  @override
  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients) {
    if (!isReady) {
      return;
    }

    // Attempt to get the texture from the render target if one was provided to the scene,
    // otherwise FskScene.setupScissor will try to find one.
    super.setupScissor(renderPass);

    Matrix4 finalMvMatrix = mvMatrix.clone();

    if (use2DLayout) {
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
    }

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

  // NOTE: Assumes a unique ID for each node, not dotted notation
  // Type safe findNode function
  T? findNode<T>(String id) {
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

        if (isReady) {
          await onSkinReady();
        }
      }

    } catch (e, stackTrace) {
      logError("Error skin XML '$skinPath': $e");
      logError("StackTrace: $stackTrace");
    }
  }
}
