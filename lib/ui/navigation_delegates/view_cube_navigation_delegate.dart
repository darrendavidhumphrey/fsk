import 'package:flutter/gestures.dart';
import 'package:vector_math/vector_math.dart';

import '../../geometry/mesh_hit_tester.dart';
import 'orbit_view_delegate.dart';

class ViewCubeNavigationDelegate extends OrbitViewDelegate {
  ViewCubeNavigationDelegate({super.viewRect,super.boxFit});

  @override
  void onPointerHover(PointerHoverEvent event) {

    Ray mouseRay = getWorldRay(event.localPosition);
    List<FskHitDetails> hit = scene.hitTest(mouseRay,mode: FskHitTestMode.closest);
    if (hit.isNotEmpty) {
      print("Hit object ${hit[0].hitObject.id}");
    } else {
      // No hit so we want the event to pass through?
      print("Miss");
    }

    super.onPointerHover(event);
  }
}