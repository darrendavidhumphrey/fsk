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



  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder to dynamically read out the exact size allocated by the parent constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        // Enforce physical constraints integers
        final int targetWidth = constraints.maxWidth.toInt();
        final int targetHeight = constraints.maxHeight.toInt();

        // Safe recalculation step before dispatching paint frames
        widget.scene.updateRenderTargetSize(targetWidth, targetHeight);

        if (widget.scene.renderTarget == null || widget.scene.texture == null) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight), // Explicitly fills layout bounds
              painter: FskScenePainter(
                scene: widget.scene,
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

  FskScenePainter({
    required this.scene,
  });

  void finishFrame(gpu.CommandBuffer commandBuffer, gpu.RenderTarget renderTarget) {
    commandBuffer.submit();
  }

  void blitImage(Canvas canvas, Size size,gpu.Texture texture) {
    final uiImage = texture.asImage();
    // 5. Blit and scale image properties directly inside our custom canvas space
    canvas.drawImageRect(
      uiImage,
      Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(scene.renderTarget!);

    scene.drawScene(renderPass,size);

    finishFrame(commandBuffer, scene.renderTarget!);
    blitImage(canvas, size, scene.texture!);
  }

  @override
  bool shouldRepaint(covariant FskScenePainter oldDelegate) {
    return oldDelegate.scene != scene;
  }
}