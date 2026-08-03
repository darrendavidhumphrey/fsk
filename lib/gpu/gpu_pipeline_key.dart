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
    this.depthCompareOperation = gpu.CompareFunction.less,
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
    vertShader = v!;
    fragShader = f!;

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
    renderPass.setDepthCompareOperation(
        depthTestEnabled ? depthCompareOperation : gpu.CompareFunction.always
    );

    // 3. Configure dynamic blending equations
    renderPass.setColorBlendEnable(true);
    renderPass.setColorBlendEquation(
      gpu.ColorBlendEquation(
        colorBlendOperation: gpu.BlendOperation.add,
        sourceColorBlendFactor: gpu.BlendFactor.one,
        destinationColorBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
        alphaBlendOperation: gpu.BlendOperation.add,
        sourceAlphaBlendFactor: gpu.BlendFactor.one,
        destinationAlphaBlendFactor: gpu.BlendFactor.oneMinusSourceAlpha,
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

// Removing the unreferenced attributes satisfies flutter_gpu
const gpu.VertexLayout v3t2Layout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes:
          48, // All Vertex Buffers have all 12 component floats
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition', // Present in shader execution graph
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aTextureCoord', // Present in shader execution graph
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),

      ],
    ),
  ],
);

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

const gpu.VertexLayout v3n3c4Layout = gpu.VertexLayout(
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
      strideInBytes: 48, // Keep the 48-byte stride so your float array reading doesn't change
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition', // Matches: layout(location = 0) in vec3 aVertexPosition;
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aTextureCoord',   // Matches: layout(location = 1) in vec2 aTextureCoord;
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),
      ],
    ),
  ],
);


const gpu.VertexLayout textVertexLayout = gpu.VertexLayout(
  buffers: [
    gpu.VertexBuffer(
      strideInBytes: 48, // Keep the 48-byte stride so your float array reading doesn't change
      stepMode: gpu.VertexStepMode.vertex,
      attributes: [
        gpu.VertexAttribute(
          name: 'aVertexPosition', // Matches: layout(location = 0) in vec3 aVertexPosition;
          format: gpu.VertexFormat.float32x3,
          offsetInBytes: 0,
        ),
        gpu.VertexAttribute(
          name: 'aTextureCoord',   // Matches: layout(location = 1) in vec2 aTextureCoord;
          format: gpu.VertexFormat.float32x2,
          offsetInBytes: 12,
        ),
      ],
    ),
  ],
);


class PipelineCache with LoggableClass {
  // Map against the stable compiled String key profile
  final Map<String, gpu.RenderPipeline> _cache = {};

  PipelineCache();

  gpu.RenderPipeline activate(
      PipelineKey key,
      gpu.RenderPass renderPass,
      gpu.VertexLayout layout,
      ) {
    // Lookup via the pre-calculated string identity token
    gpu.RenderPipeline? pipeline = _cache[key.uniqueStringKey];

    if (pipeline == null) {
      //logInfo("COMPILING PIPELINE FOR: ${key.uniqueStringKey}");
      pipeline = gpu.gpuContext.createRenderPipeline(
        key.vertShader,
        key.fragShader,
        vertexLayout: layout,
      );

      _cache[key.uniqueStringKey] = pipeline;
    }
    renderPass.bindPipeline(pipeline);
    key.applyPipelineStates(renderPass);

    return pipeline;
  }
}