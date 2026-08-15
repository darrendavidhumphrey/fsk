import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:fsk/fsk.dart';

class PipelineKey with LoggableClass {
  final String vertShaderName;
  final String fragShaderName;
  final String layoutName;
  late gpu.Shader vertShader;
  late gpu.Shader fragShader;

  final bool depthTestEnabled;
  final bool depthWriteEnabled;
  final gpu.CompareFunction depthCompareOperation;
  final bool texturingEnabled;
  final gpu.BlendFactor srcColorFactor;
  final gpu.BlendFactor dstColorFactor;
  final gpu.BlendFactor srcAlphaFactor;
  final gpu.BlendFactor dstAlphaFactor;
  final gpu.BlendOperation colorBlendOp;
  final gpu.BlendOperation alphaBlendOp;
  final gpu.WindingOrder windingOrder;
  final gpu.CullMode cullMode;

  // Cache the key string directly at constructor initialization time
  late final String uniqueStringKey;

  PipelineKey({
    required this.vertShaderName,
    required this.fragShaderName,
    required this.layoutName,
    this.depthTestEnabled = false,
    this.depthWriteEnabled = false,
    this.depthCompareOperation = gpu.CompareFunction.lessEqual,
    this.texturingEnabled = false,
    this.srcColorFactor = gpu.BlendFactor.sourceAlpha,
    this.dstColorFactor = gpu.BlendFactor.oneMinusSourceAlpha,
    this.srcAlphaFactor = gpu.BlendFactor.one,
    this.dstAlphaFactor = gpu.BlendFactor.oneMinusSourceAlpha,
    this.colorBlendOp = gpu.BlendOperation.add,
    this.alphaBlendOp = gpu.BlendOperation.add,
    this.windingOrder = gpu.WindingOrder.counterClockwise,
    this.cullMode = gpu.CullMode.none,
  }) {
    var v = FSK().shaderLibrary[vertShaderName];
    var f = FSK().shaderLibrary[fragShaderName];
    
    if (v == null || f == null) {
      final missing = v == null ? vertShaderName : fragShaderName;
      throw StateError("PipelineKey: Shader '$missing' not found in library.");
    }
    
    vertShader = v;
    fragShader = f;

    // PRE-CREATE AN ABSOLUTE STRING IDENTITY SIGNATURE
    uniqueStringKey = [
      vertShaderName,
      fragShaderName,
      layoutName,
      depthTestEnabled ? '1' : '0',
      depthWriteEnabled ? '1' : '0',
      depthCompareOperation.index,
      texturingEnabled ? '1' : '0',
      srcColorFactor.index,
      dstColorFactor.index,
      srcAlphaFactor.index,
      dstAlphaFactor.index,
      colorBlendOp.index,
      alphaBlendOp.index,
      windingOrder.index,
      cullMode.index,
    ].join('|');
  }

  void applyPipelineStates(gpu.RenderPass renderPass) {
    // 1. Configure dynamic primitive attributes
    renderPass.setCullMode(cullMode);
    renderPass.setWindingOrder(windingOrder);

    // 2. Configure dynamic depth testing structures
    renderPass.setDepthWriteEnable(depthWriteEnabled);
    if (depthTestEnabled) {
      renderPass.setDepthCompareOperation(depthCompareOperation);
    } else {
      renderPass.setDepthCompareOperation(gpu.CompareFunction.always);
    }

    // 3. Configure dynamic blending equations
    renderPass.setColorBlendEnable(true);
    renderPass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: colorBlendOp,
        sourceColorBlendFactor: srcColorFactor,
        destinationColorBlendFactor: dstColorFactor,
        alphaBlendOperation: alphaBlendOp,
        sourceAlphaBlendFactor: srcAlphaFactor,
        destinationAlphaBlendFactor: dstAlphaFactor,
      ),
    );

    renderPass.setStencilConfig(
      gpu.StencilConfig(
        compareFunction: gpu.CompareFunction.always,
        stencilFailureOperation: gpu.StencilOperation.keep,
        depthFailureOperation: gpu.StencilOperation.keep,
        depthStencilPassOperation: gpu.StencilOperation.keep,
      ),
      targetFace: gpu.StencilFace.both,
    );
    renderPass.setStencilReference(0);
  }


  // FORCE equality checking straight over the unique static string signatures
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is PipelineKey && uniqueStringKey == other.uniqueStringKey;

  @override
  int get hashCode => uniqueStringKey.hashCode;
}

const gpu.VertexLayout v3t2n3c4Layout = gpu.VertexLayout(
  buffers: [
    // Slot 0: Our main interleaved vertex buffer
    gpu.VertexBuffer(
      strideInBytes: 48, // 12 total floats * 4 bytes per element
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        // 📍 Position Attribute (vec3 / float32x3)
        // Takes 12 bytes. Starts at byte 0.
        gpu.VertexAttribute(
          name:
              'aVertexPosition', // Must exactly match the input name in your vertex shader
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),

        // 📍 Texture Coordinate Attribute (vec2 / float32x2)
        // Takes 8 bytes. Starts at byte 12 (after position).
        gpu.VertexAttribute(
          name: 'aTextureCoord',
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),

        // 📍 Normal Attribute (vec3 / float32x3)
        // Takes 12 bytes. Starts at byte 20 (12 + 8).
        gpu.VertexAttribute(
          name: 'aVertexNormal',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 20,
        ),

        // 📍 Color Attribute (vec4 / float32x4)
        // Takes 16 bytes. Starts at byte 32 (20 + 12).
        gpu.VertexAttribute(
          name: 'aVertexColor',
          format: gpu.VertexFormat.float32x4,
          offsetInBytes: 32,
        ),
      ],
    ),
  ],
);

const gpu.VertexLayout quadVertexLayout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes: 48,
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aTextureCoord',
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),
      ],
    ),
  ],
);

const gpu.VertexLayout textVertexLayout = quadVertexLayout;
const gpu.VertexLayout v3t2Layout = quadVertexLayout;

const gpu.VertexLayout v3n3Layout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes: 48,
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aVertexNormal',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 20,
        ),
      ],
    ),
  ],
);

const gpu.VertexLayout v3t2n3Layout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes: 48,
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aTextureCoord',
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),
        gpu.VertexAttribute(
          name: 'aVertexNormal',
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 20,
        ),
      ],
    ),
  ],
);


class PipelineCache with LoggableClass {
  // Map against the stable compiled String key profile
  final Map<String, gpu.RenderPipeline> _cache = {};

  PipelineCache();

  void clear() {
    _cache.clear();
  }

  gpu.RenderPipeline activate(
    PipelineKey key,
    gpu.RenderPass renderPass,
    gpu.VertexLayout layout,
  ) {
    gpu.RenderPipeline? pipeline = _cache[key.uniqueStringKey];
    if (pipeline == null) {
      logInfo("PipelineCache: building NEW pipeline: ${key.uniqueStringKey}");
      try {
        pipeline = gpu.gpuContext.createRenderPipeline(
          key.vertShader,
          key.fragShader,
          vertexLayout: layout,
        );
        _cache[key.uniqueStringKey] = pipeline;
      } catch (e) {
        logError("PipelineCache: FAILED to build pipeline: ${key.uniqueStringKey}\n$e");
        rethrow;
      }
    }

    renderPass.bindPipeline(pipeline);
    key.applyPipelineStates(renderPass);

    return pipeline;
  }
}