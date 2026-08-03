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

    if (width == 0 || height == 0) return Matrix4.identity();

    // Mapping world [-width/2, width/2] -> NDC [-1, 1]
    // And world [-height/2, height/2] -> NDC [-1, 1]
    // This assumes the world origin (0,0) is the center of the viewport.
    // Impeller (Vulkan/Metal style) NDC has Y=-1 at the top.
    Matrix4 proj = Matrix4.zero();
    proj.setEntry(0, 0, 2.0 / width);
    proj.setEntry(1, 1, 2.0 / height);
    
    // Map Z to [0, 1] (Impeller/Vulkan style)
    proj.setEntry(2, 2, 1.0 / (far - near));
    proj.setEntry(2, 3, -near / (far - near));
    proj.setEntry(3, 3, 1.0);
    
    return proj;
  }
}
