import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' show Matrix4;

/// An abstract base class for a 3D scene, representing the root of a scene graph.
abstract class FskScene extends ChangeNotifier with LoggableClass {
  Matrix4 pMatrix = Matrix4.identity();
  Matrix4 mvMatrix = Matrix4.identity();

  Size _viewportSize = Size.zero;
  // ignore: unnecessary_getters_setters
  Size get viewportSize => _viewportSize;
  set viewportSize(Size value) => _viewportSize = value;

  FskSceneNavigationDelegate? navigationDelegate;


  gpu.Texture? _texture;
  // ignore: unnecessary_getters_setters
  gpu.Texture? get texture => _texture;
  set texture(gpu.Texture? value) => _texture = value;

  Color clearColor = Colors.black;

  bool isReady = true;

  FskScene({this.navigationDelegate}) {
    navigationDelegate?.setScene(this);
  }

  void setNeedsUpdate() {
    notifyListeners();
  }

  void updateRenderTargetSize(int width, int height) {
    // Communication in PHYSICAL pixels for the GPU surface
    _viewportSize = Size(width.toDouble(), height.toDouble());

    // Communication in LOGICAL pixels for the Navigation Logic and Projections
    navigationDelegate?.setViewRect(
      Rect.fromLTWH(0, 0, width / FSK.devicePixelRatio, height / FSK.devicePixelRatio),
    );
  }

  void setupScissor(gpu.RenderPass renderPass) {
    navigationDelegate?.updateSceneMatrices();

    if (_texture == null) return;

    renderPass.setScissor(
      gpu.Scissor(x: 0, y: 0, width: _texture!.width, height: _texture!.height),
    );

    renderPass.setViewport(
      gpu.Viewport(x: 0, y: 0, width: _texture!.width, height: _texture!.height),
    );
  }

  void drawScene(gpu.RenderPass renderPass, gpu.HostBuffer transients);
  void rebuildGeometry() {}
  void clearRetainedBuffers() {}
}
