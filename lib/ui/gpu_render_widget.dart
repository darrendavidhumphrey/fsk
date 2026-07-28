import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class GPURenderWidget extends StatefulWidget {
  final FskScene scene;

  const GPURenderWidget({required this.scene, super.key});

  @override
  State<GPURenderWidget> createState() => _GPURenderWidgetState();
}

class _GPURenderWidgetState extends State<GPURenderWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Size _lastSize = Size.zero;
  FskScene? _lastScene; // Track which scene instance was drawn last

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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

    // FIX: Force texture allocation if the dimensions OR the scene instance changed
    if (_lastSize != logicalSize || _lastScene != widget.scene) {
      _lastSize = logicalSize;
      _lastScene = widget.scene; // Lock onto the new scene instance

      widget.scene.updateRenderTargetSize(physicalWidth, physicalHeight);
      widget.scene.allocateRenderTarget();
      widget.scene.viewportSize = Size(physicalWidth.toDouble(), physicalHeight.toDouble());
    }

    // Rebuild VBOs/Geometry on the CPU
    widget.scene.rebuildGeometry();

    // Record and dispatch commands to GPU
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(widget.scene.renderTarget!);
    final gpu.HostBuffer frameTransients = gpu.gpuContext.createHostBuffer();

    widget.scene.drawScene(renderPass, frameTransients);
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
          animation: _animationController,
          builder: (context, child) {
            _processGpuFrame(logicalSize, pixelRatio);

            return CustomPaint(
              size: logicalSize,
              painter: FskScenePainter(
                scene: widget.scene,
                pixelRatio: pixelRatio,
                repaintTrigger: _animationController.value,
              ),
            );
          },
        );
      },
    );
  }
}



class FskScenePainter extends CustomPainter {
  final FskScene scene;
  final double pixelRatio;
  final double repaintTrigger;

  FskScenePainter({
    required this.scene,
    required this.pixelRatio,
    required this.repaintTrigger,
  }) : super(repaint: ValueNotifier(repaintTrigger));

  @override
  void paint(Canvas canvas, Size size) {
    // FIX: Safely early-out if the scene structure is not fully initialized
    if (scene.isReady == false || scene.texture == null) {
      return;
    }

    // Capture the texture asset safely without using the "!" operator
    final texture = scene.texture;
    if (texture == null) return;

    final uiImage = texture.asImage();

    // Scale from physical dimensions back to match logical coordinates
    canvas.save();
    canvas.scale(1.0 / pixelRatio);

    canvas.drawImage(uiImage, Offset.zero, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FskScenePainter oldDelegate) {
    return oldDelegate.scene != scene || oldDelegate.repaintTrigger != repaintTrigger;
  }
}


