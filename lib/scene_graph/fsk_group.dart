import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart';

import '../frames/frame_data.dart';

class FskGroup extends FskRenderableObject {
  final List<FskSceneObject> children = [];
  late final Vector3 _anchor;

  /////////////////////////////////////////////////////////////////////////////
  // Constructor
  /////////////////////////////////////////////////////////////////////////////
  FskGroup(super.id,super.parentScene,this._anchor);

  FskGroup.fromData(super.id,super.parentScene, FrameGroupData data) {
    _anchor = data.anchor;
    visible = data.visible;
  }

  @override
  void draw(
      gpu.RenderPass renderPass,
      gpu.HostBuffer transients,
      Matrix4 pMatrix,
      Matrix4 mvMatrix,
      ) {
    if (!visible) return;

    // Create the child object's local translation matrix
    final Matrix4 localTranslation = Matrix4.identity()
      ..translateByVector3(_anchor);


    // Pass down the fully computed local-to-world context downward
    for (var child in children) {
      // Clone the incoming matrix to ensure absolute isolation between child branches
      final Matrix4 mvTrans = mvMatrix.clone()..multiply(localTranslation);

      if (child is FskRenderableObject) {
        child.draw(renderPass, transients, pMatrix, mvTrans);
      }
    }
  }

  @override
  void rebuildGeometry() {
    for (var child in children) {
      child.rebuildGeometry();
    }
  }

  @override
  void doRebuild() {
    // TODO: implement doRebuild
  }

  @override
  void rebuildPipelineIfNeeded() {
    // TODO: implement rebuildPipelineIfNeeded
  }
}