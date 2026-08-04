import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/scene_graph/fsk_scene_object.dart';

class FskDepthState {
  bool depthTestEnabled;
  bool depthWriteEnabled;
  gpu.CompareFunction depthCompareOperation;

  FskDepthState({
    this.depthTestEnabled = true,
    this.depthWriteEnabled = true,
    this.depthCompareOperation = gpu.CompareFunction.less,
  });

  void setDepthState({
    bool? depthTestEnabled,
    bool? depthWriteEnabled,
    gpu.CompareFunction? depthCompareOperation,
  }) {
    if (depthTestEnabled != null) this.depthTestEnabled = depthTestEnabled;
    if (depthWriteEnabled != null) this.depthWriteEnabled = depthWriteEnabled;
    if (depthCompareOperation != null) this.depthCompareOperation = depthCompareOperation;
  }
}

mixin FskDepthStateMixin on FskRenderableObject {
  bool get depthTestEnabled => renderer.depthState.depthTestEnabled;
  set depthTestEnabled(bool value) {
    renderer.depthState.depthTestEnabled = value;
    renderer.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }

  bool get depthWriteEnabled => renderer.depthState.depthWriteEnabled;
  set depthWriteEnabled(bool value) {
    renderer.depthState.depthWriteEnabled = value;
    renderer.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }

  gpu.CompareFunction get depthCompareOperation => renderer.depthState.depthCompareOperation;
  set depthCompareOperation(gpu.CompareFunction value) {
    renderer.depthState.depthCompareOperation = value;
    renderer.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }

  void setDepthState({
    bool? depthTestEnabled,
    bool? depthWriteEnabled,
    gpu.CompareFunction? depthCompareOperation,
  }) {
    renderer.depthState.setDepthState(
      depthTestEnabled: depthTestEnabled,
      depthWriteEnabled: depthWriteEnabled,
      depthCompareOperation: depthCompareOperation,
    );
    renderer.pipeLineNeedsRebuild = true;
    parentScene.setNeedsUpdate();
  }
}
