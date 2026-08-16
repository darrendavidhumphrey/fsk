import 'dart:ui' as ui;
import 'package:flutter_gpu/gpu.dart' as gpu;

import '../util.dart';
import '../logging.dart';

class FskRenderTarget with LoggableClass {
  final int width;
  final int height;
  final bool enableMsaa;

  gpu.Texture? _msaaColorTexture;
  gpu.Texture? _resolveTexture;
  gpu.Texture? _depthTexture;
  
  gpu.RenderTarget? _renderTargetClear;
  gpu.RenderTarget? _renderTargetLoad;
  gpu.RenderTarget? _renderTargetLoadClearDepth;
  gpu.RenderTarget? _renderTargetResolveOnly;

  ui.Color clearColor;

  FskRenderTarget({
    required this.width,
    required this.height,
    required this.enableMsaa,
    required this.clearColor,
  }) {
    _allocateResources();
  }

  // Simplified Selection API: Root pass clears, others load.
  // Resolve is always handled by a separate pass or the final step.
  gpu.RenderTarget get clearTarget => _renderTargetClear!;
  gpu.RenderTarget get loadTarget => _renderTargetLoad!;
  gpu.RenderTarget get loadClearDepthTarget => _renderTargetLoadClearDepth!;
  gpu.RenderTarget get resolveOnlyTarget => _renderTargetResolveOnly!;

  gpu.Texture get outputTexture => _resolveTexture!;

  int get sampleCount {
    if (!enableMsaa) return 1;
    bool supported = gpu.gpuContext.doesSupportOffscreenMSAA;
    logInfo("FskRenderTarget: Hardware MSAA support: $supported");
    if (!supported) return 1;
    return 4;
  }

  void _allocateResources() {
    final int samples = sampleCount;
    logInfo("FskRenderTarget: allocating ($width x $height), samples: $samples");

    _resolveTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible, width, height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
      enableRenderTargetUsage: true, enableShaderReadUsage: true,
    );

    _depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate, width, height,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      sampleCount: samples,
    );

    final depthClear = gpu.DepthStencilAttachment(
      texture: _depthTexture!, depthClearValue: 1.0,
      depthLoadAction: gpu.LoadAction.clear, depthStoreAction: gpu.StoreAction.store, 
    );
    final depthLoad = gpu.DepthStencilAttachment(
      texture: _depthTexture!, depthLoadAction: gpu.LoadAction.load, depthStoreAction: gpu.StoreAction.store,
    );

    if (samples > 1) {
      _msaaColorTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate, width, height,
        format: gpu.PixelFormat.r8g8b8a8UNormInt,
        sampleCount: samples, enableRenderTargetUsage: true,
      );

      final clearVec = colorToVector(clearColor);

      // We use STORE for all drawing passes to keep the MSAA data valid.
      _renderTargetClear = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _msaaColorTexture!, clearValue: clearVec, 
          loadAction: gpu.LoadAction.clear, storeAction: gpu.StoreAction.store,
        )],
        depthStencilAttachment: depthClear,
      );

      _renderTargetLoad = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _msaaColorTexture!, loadAction: gpu.LoadAction.load, storeAction: gpu.StoreAction.store,
        )],
        depthStencilAttachment: depthLoad,
      );

      _renderTargetLoadClearDepth = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _msaaColorTexture!, loadAction: gpu.LoadAction.load, storeAction: gpu.StoreAction.store,
        )],
        depthStencilAttachment: depthClear,
      );

      // This pass does nothing but resolve the final MSAA buffer to the single-sample texture.
      _renderTargetResolveOnly = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _msaaColorTexture!, resolveTexture: _resolveTexture!,
          loadAction: gpu.LoadAction.load, storeAction: gpu.StoreAction.multisampleResolve,
        )],
      );
    } else {
      // Single Sample Path: Resolve is the Texture itself.
      _renderTargetClear = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _resolveTexture!, clearValue: colorToVector(clearColor),
          loadAction: gpu.LoadAction.clear, storeAction: gpu.StoreAction.store,
        )],
        depthStencilAttachment: depthClear,
      );

      _renderTargetLoad = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _resolveTexture!, loadAction: gpu.LoadAction.load, storeAction: gpu.StoreAction.store,
        )],
        depthStencilAttachment: depthLoad,
      );

      _renderTargetLoadClearDepth = gpu.RenderTarget(
        colorAttachments: [gpu.ColorAttachment(
          texture: _resolveTexture!, loadAction: gpu.LoadAction.load, storeAction: gpu.StoreAction.store,
        )],
        depthStencilAttachment: depthClear,
      );
      
      _renderTargetResolveOnly = _renderTargetLoad;
    }
  }
}
