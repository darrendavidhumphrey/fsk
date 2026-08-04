import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class GPURenderWidget extends StatefulWidget {
  final FskScene scene;
  final bool useAntiAliasing;

  const GPURenderWidget({required this.scene, super.key,this.useAntiAliasing=false});

  @override
  State<GPURenderWidget> createState() => _GPURenderWidgetState();
}

class _GPURenderWidgetState extends State<GPURenderWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Listenable _repaintListenable;

  Size _lastSize = Size.zero;
  FskScene? _lastScene;
  FskRenderTarget? _fskTarget;
  Color? _lastClearColor;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _repaintListenable = Listenable.merge([_animationController, widget.scene]);
  }

  @override
  void didUpdateWidget(covariant GPURenderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene) {
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

    final int physicalWidth = (logicalSize.width * pixelRatio).round();
    final int physicalHeight = (logicalSize.height * pixelRatio).round();

    // Reallocate container explicitly if size transforms, scene instances, or clear colors change
    if (_lastSize != logicalSize || _lastScene != widget.scene || _lastClearColor != widget.scene.clearColor) {
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

    widget.scene.rebuildGeometry();

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final gpu.HostBuffer frameTransients = gpu.gpuContext.createHostBuffer();

    // Inform your pipeline states of your chosen sample layout rules
    widget.scene.drawScene(commandBuffer, _fskTarget!, frameTransients);

    commandBuffer.submit();
    widget.scene.clearRetainedBuffers();
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
            _processGpuFrame(logicalSize, pixelRatio);

            return CustomPaint(
              size: logicalSize,
              painter: FskScenePainter(
                // Safely blit the completed output texture reference
                texture: _fskTarget?.outputTexture,
                pixelRatio: pixelRatio,
                repaintTrigger: _repaintListenable,
              ),
            );
          },
        );
      },
    );
  }
}

class FskScenePainter extends CustomPainter {
  final gpu.Texture? texture;
  final double pixelRatio;
  final Listenable repaintTrigger;

  FskScenePainter({
    required this.texture,
    required this.pixelRatio,
    required this.repaintTrigger,
  }) : super(repaint: repaintTrigger);

  @override
  void paint(Canvas canvas, Size size) {
    // Don't paint if there's no surface top paint
    if (texture == null) {
      return;
    }

    final uiImage = texture!.asImage();

    // Scale from physical dimensions back to match logical coordinates
    canvas.save();
    canvas.scale(1.0 / pixelRatio);

    canvas.drawImage(uiImage, Offset.zero, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FskScenePainter oldDelegate) {
    return oldDelegate.texture != texture || oldDelegate.repaintTrigger != repaintTrigger;
  }
}


