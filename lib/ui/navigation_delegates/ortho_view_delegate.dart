import 'package:fsk/ui/navigation_delegates/scene_navigation_delegate.dart';
import 'package:vector_math/vector_math.dart';

class OrthoViewDelegate extends FskSceneNavigationDelegate {
  OrthoViewDelegate({super.viewRect, super.boxFit});

  @override
  Matrix4 createViewMatrix() => Matrix4.identity();

  @override
  Matrix4 createProjectionMatrix() {
    final double width = viewRect.width;
    final double height = viewRect.height;
    final double near = -1000.0;
    final double far = 1000.0;

    Matrix4 proj = Matrix4.zero();
    proj.setEntry(0, 0, 2.0 / width);
    proj.setEntry(1, 1, 2.0 / height);
    proj.setEntry(2, 2, 1.0 / (far - near));
    proj.setEntry(2, 3, -near / (far - near));
    proj.setEntry(3, 3, 1.0);
    
    return proj;
  }
}
