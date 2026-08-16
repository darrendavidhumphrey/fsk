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
  gpu.RenderTarget? _renderTargetLoadColorClearDepth;
  ui.Color clearColor;

  FskRenderTarget({
    required this.width,
    required this.height,
    required this.enableMsaa,
    required this.clearColor,
  }) {
    _allocateResources();
  }

  gpu.RenderTarget get renderTarget => _renderTargetClear!;
  gpu.RenderTarget get loadTarget => _renderTargetLoad!;
  gpu.RenderTarget get loadColorClearDepthTarget => _renderTargetLoadColorClearDepth!;
  gpu.Texture get outputTexture => _resolveTexture!;

  int get sampleCount {
    if (!enableMsaa) return 1;
    // Strictly check hardware support for offscreen MSAA
    if (!gpu.gpuContext.doesSupportOffscreenMSAA) return 1;
    return 4;
  }

  void _allocateResources() {
    final int targetSampleCount = sampleCount;
    logInfo("FskRenderTarget: allocating resources ($width x $height), MSAA samples: $targetSampleCount");

    _resolveTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.hostVisible,
      width,
      height,
      format: gpu.PixelFormat.r8g8b8a8UNormInt,
      enableRenderTargetUsage: true,
      enableShaderReadUsage: true,
    );

    // Ensure the depth buffer ALWAYS matches the color buffer's sample count
    _depthTexture = gpu.gpuContext.createTexture(
      gpu.StorageMode.devicePrivate,
      width,
      height,
      format: gpu.gpuContext.defaultDepthStencilFormat,
      enableRenderTargetUsage: true,
      sampleCount: targetSampleCount,
    );

    final depthAttachmentClear = gpu.DepthStencilAttachment(
      texture: _depthTexture!,
      depthClearValue: 1.0,
      depthLoadAction: gpu.LoadAction.clear,
      depthStoreAction: gpu.StoreAction.store, 
    );

    final depthAttachmentLoad = gpu.DepthStencilAttachment(
      texture: _depthTexture!,
      depthLoadAction: gpu.LoadAction.load,
      depthStoreAction: gpu.StoreAction.store,
    );

    if (targetSampleCount > 1) {
      _msaaColorTexture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate,
        width,
        height,
        format: gpu.PixelFormat.r8g8b8a8UNormInt,
        sampleCount: targetSampleCount,
        enableRenderTargetUsage: true,
        enableShaderReadUsage: false,
      );

      final colorAttachmentClear = gpu.ColorAttachment(
        texture: _msaaColorTexture!,
        resolveTexture: _resolveTexture!,
        clearValue: colorToVector(clearColor),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.multisampleResolve,
      );

      final colorAttachmentLoad = gpu.ColorAttachment(
        texture: _msaaColorTexture!,
        resolveTexture: _resolveTexture!,
        loadAction: gpu.LoadAction.load,
        storeAction: gpu.StoreAction.multisampleResolve,
      );

      _renderTargetClear = gpu.RenderTarget(
        colorAttachments: [colorAttachmentClear],
        depthStencilAttachment: depthAttachmentClear,
      );

      _renderTargetLoad = gpu.RenderTarget(
        colorAttachments: [colorAttachmentLoad],
        depthStencilAttachment: depthAttachmentLoad,
      );

      _renderTargetLoadColorClearDepth = gpu.RenderTarget(
        colorAttachments: [colorAttachmentLoad],
        depthStencilAttachment: depthAttachmentClear,
      );
    } else {
      final colorAttachmentClear = gpu.ColorAttachment(
        texture: _resolveTexture!,
        clearValue: colorToVector(clearColor),
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.store,
      );

      final colorAttachmentLoad = gpu.ColorAttachment(
        texture: _resolveTexture!,
        loadAction: gpu.LoadAction.load,
        storeAction: gpu.StoreAction.store,
      );

      _renderTargetClear = gpu.RenderTarget(
        colorAttachments: [colorAttachmentClear],
        depthStencilAttachment: depthAttachmentClear,
      );

      _renderTargetLoad = gpu.RenderTarget(
        colorAttachments: [colorAttachmentLoad],
        depthStencilAttachment: depthAttachmentLoad,
      );

      _renderTargetLoadColorClearDepth = gpu.RenderTarget(
        colorAttachments: [colorAttachmentLoad],
        depthStencilAttachment: depthAttachmentClear,
      );
    }
  }
}
