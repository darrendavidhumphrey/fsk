import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/scene_graph/fsk_scene.dart';
import 'package:fsk/scene_graph/fsk_scene_base.dart';
import 'package:fsk/fsk_singleton.dart';
import 'package:fsk/gpu/fsk_render_target.dart';
import 'package:fsk/logging.dart';

class GPURenderWidget extends StatefulWidget {
  final FskSceneBase scene;
  final bool useAntiAliasing;
  final bool isAnimating;

  const GPURenderWidget({
    required this.scene, 
    super.key, 
    this.useAntiAliasing = true,
    this.isAnimating = true,
  });

  @override
  State<GPURenderWidget> createState() => _GPURenderWidgetState();
}

class _GPURenderWidgetState extends State<GPURenderWidget> with SingleTickerProviderStateMixin, LoggableClass {
  late AnimationController _animationController;
  late Listenable _repaintListenable;

  Size _lastSize = Size.zero;
  FskSceneBase? _lastScene;
  FskRenderTarget? _fskTarget;
  Color? _lastClearColor;
  bool _isProcessingFrame = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    
    if (widget.isAnimating) {
      _animationController.repeat();
    }

    _repaintListenable = Listenable.merge([_animationController, widget.scene]);
  }

  @override
  void didUpdateWidget(covariant GPURenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene || oldWidget.isAnimating != widget.isAnimating) {
      if (widget.isAnimating) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
      _repaintListenable = Listenable.merge([_animationController, widget.scene]);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _processGpuFrame(Size logicalSize, double pixelRatio) {
    if (!widget.scene.isReady) return;
    if (_isProcessingFrame) return;

    FSK.devicePixelRatio = pixelRatio;
    _isProcessingFrame = true;
    try {
      final int physicalWidth = (logicalSize.width * pixelRatio).round();
      final int physicalHeight = (logicalSize.height * pixelRatio).round();

      if (physicalWidth <= 0 || physicalHeight <= 0) return;

      // Reallocate container explicitly if size transforms, scene instances, clear colors, or MSAA settings change
      if (_lastSize != logicalSize || 
          _lastScene != widget.scene || 
          _lastClearColor != widget.scene.clearColor || 
          _fskTarget?.enableMsaa != widget.useAntiAliasing) {
        _lastSize = logicalSize;
        _lastScene = widget.scene;
        _lastClearColor = widget.scene.clearColor;

        // Update dimensions
        widget.scene.updateRenderTargetSize(physicalWidth, physicalHeight);
        widget.scene.viewportSize = Size(physicalWidth.toDouble(), physicalHeight.toDouble());

        // Instantiate the container wrapper cleanly
        _fskTarget = FskRenderTarget(
          width: physicalWidth,
          height: physicalHeight,
          enableMsaa: widget.useAntiAliasing,
          clearColor: widget.scene.clearColor,
        );
        widget.scene.texture = _fskTarget!.outputTexture;
      }

      widget.scene.updateAnimations(DateTime.now());
      // logVerbose("GPURenderWidget: Rebuilding geometry...");
      widget.scene.rebuildGeometry();

      final commandBuffer = gpu.gpuContext.createCommandBuffer();
      final gpu.HostBuffer frameTransients = gpu.gpuContext.createHostBuffer();

      // Inform your pipeline states of your chosen sample layout rules
      widget.scene.drawScene(commandBuffer, _fskTarget!, frameTransients);

      // Perform a final resolve pass to get the multi-sampled data into the resolve texture.
      // This pass doesn't draw anything, it just triggers the GPU's resolve logic 
      // for the entire screen, ensuring no trails and clean MSAA.
      final resolvePass = commandBuffer.createRenderPass(_fskTarget!.resolveOnlyTarget);
      // No draw calls needed, resolve happens at pass end automatically.

      commandBuffer.submit();
      widget.scene.clearRetainedBuffers();
    } catch (e, s) {
      logError("Exception in GPURenderWidget _processGpuFrame: $e\n$s");
    } finally {
      _isProcessingFrame = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size logicalSize = Size(constraints.maxWidth, constraints.maxHeight);

        return AnimatedBuilder(
          animation: _repaintListenable,
          builder: (context, child) {
            if (!widget.scene.isReady) {
              return Container(color: widget.scene.clearColor);
            }

            try {
              _processGpuFrame(logicalSize, pixelRatio);
            } catch (e, s) {
              logError("Exception in GPURenderWidget builder: $e\n$s");
            }

            if (_fskTarget == null) {
              return Container(color: widget.scene.clearColor);
            }

            return ValueListenableBuilder<MouseCursor>(
              valueListenable: widget.scene.cursorNotifier,
              builder: (context, cursor, _) {
                return MouseRegion(
                  cursor: cursor,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: logicalSize,
                        painter: FskScenePainter(
                          scene: widget.scene,
                          // Safely blit the completed output texture reference
                          texture: _fskTarget?.outputTexture,
                          pixelRatio: pixelRatio,
                          repaintTrigger: _repaintListenable,
                        ),
                      ),
                      // Render Widget Portals 
                      if (widget.scene is FskScene)
                        ...((widget.scene as FskScene).widgetPortals.map((portal) {
                          return Positioned(
                            left: 0,
                            top: 0,
                            child: Opacity(
                              opacity: 0.01, // Nearly invisible but still mounted and active
                              child: SizedBox(
                                width: portal.size.width,
                                height: portal.size.height,
                                child: RepaintBoundary(
                                  key: portal.repaintKey,
                                  child: portal.widget,
                                ),
                              ),
                            ),
                          );
                        })).toList(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class FskScenePainter extends CustomPainter with LoggableClass {
  final FskSceneBase scene;
  final gpu.Texture? texture;
  final double pixelRatio;
  final Listenable repaintTrigger;

  FskScenePainter({
    required this.scene,
    required this.texture,
    required this.pixelRatio,
    required this.repaintTrigger,
  }) : super(repaint: repaintTrigger);

  @override
  void paint(Canvas canvas, Size size) {
    // Don't paint if there's no surface to paint
    if (texture == null) {
      return;
    }

    try {
      final uiImage = texture!.asImage();

      // Scale from physical dimensions back to match logical coordinates
      canvas.save();
      canvas.scale(1.0 / pixelRatio);

      canvas.drawImage(uiImage, Offset.zero, Paint());
      canvas.restore();

      // Test hook: Capture a handle for the test harness if requested
      if (scene.captureRequested) {
        scene.onFrameCaptured(uiImage);
      } else {
        // Normal frame: explicitly dispose to prevent GPU leaks
        uiImage.dispose();
      }
    } catch (e, s) {
      logError("Exception in FskScenePainter.paint: $e\n$s");
    }
  }

  @override
  bool shouldRepaint(covariant FskScenePainter oldDelegate) {
    return oldDelegate.texture != texture || 
           oldDelegate.repaintTrigger != repaintTrigger ||
           scene.captureRequested;
  }
}
