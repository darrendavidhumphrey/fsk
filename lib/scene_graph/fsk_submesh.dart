import '../gpu/fsk_texture_manager.dart';
import '../shaders/materials.dart';

class FskSubMesh {
  final int count;
  final int offset;
  final String? materialName;
  FskTextureInfo? textureInfo;
  GlMaterial? material;

  FskSubMesh({
    required this.count,
    required this.offset,
    this.materialName,
    this.textureInfo,
    this.material,
  });

  // Compatibility and semantic aliases
  int get indexCount => count;
  int get firstIndex => offset;
  int get vertexCount => count;
  int get firstVertex => offset;
}
