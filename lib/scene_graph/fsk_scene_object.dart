import 'package:vector_math/vector_math_64.dart';

import '../angle/gl_state_manager.dart';

abstract class FskSceneObject {

  void drawSetup(GlStateManager gls, Matrix4 pMatrix, Matrix4 mvMatrix);
  void draw(GlStateManager gls);
  void init(GlStateManager gls);
  void rebuild(GlStateManager gls);
  void dispose();

  void applyShaderParams(Map<String, String> params);
}
