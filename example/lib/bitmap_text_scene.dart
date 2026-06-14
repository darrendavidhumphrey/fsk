import 'package:flutter/material.dart';
import 'package:flutter_angle/flutter_angle.dart';
import 'package:fsg/fsg.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

class BitmapTextScene extends Scene {
  BitmapTextScene();

  List<BitmapText> textItems = [];
  BitmapText? dynamicTextItem;

  @override
  void dispose() {}

  @override
  void init(RenderingContext gl) {
    super.init(gl);

    loadCustomFonts();
  }

  void loadCustomFonts() {
    BitmapFontManager().createFontFromFile(
      "Arial36",
      "assets/Arial36.fnt",
      "Arial36.png",
    );

    BitmapFontManager().createFontFromFile(
      "Scoreboard140",
      "assets/Scoreboard140.fnt",
      "Scoreboard140.png",
    );
  }

  void createTextItems() {
    // Can't create text items until the default font is created
    if (BitmapFontManager().defaultFont == null) return;

    BitmapFont defaultFont = BitmapFontManager().defaultFont!;

    textItems.add(
      BitmapText.origin(
        text: "HELLO WORLD",
        font: defaultFont,
        origin: Vector3(0, 0, 0),
        width: 100,
      ),
    );

    BitmapFont arial36 = BitmapFontManager().getFont("Arial36")!;
    textItems.add(
      BitmapText.origin(
        text: "Arial Text",
        font: arial36,
        origin: Vector3(0, 100, 0),
        width: 100,
      ),
    );

    BitmapFont scoreboard = BitmapFontManager().getFont("Scoreboard140")!;

    dynamicTextItem = BitmapText.origin(
      text: "0123456789",
      font: scoreboard,
      origin: Vector3(0, 75, 0),
      color: Colors.red,
      width: 100,
    );
    textItems.add(dynamicTextItem!);
  }

  void updateTextItems() {
    if (textItems.isEmpty) {
      createTextItems();
    }

    dynamicTextItem?.setText("$frameCounter");
    for (BitmapText child in textItems) {
      if (child.needsRebuild) {
        child.rebuild(gl);
      }
    }
  }

  @override
  void drawScene() async {
    super.drawScene();
    updateTextItems();

    if (textItems.isEmpty) {
      requestRepaint();
      return;
    }


    gls.setViewport(
      0,
      0,
      FSG.renderToTextureSize.toInt(),
      FSG.renderToTextureSize.toInt(),
    );
    gls.activeTexture(WebGL.TEXTURE0);
    gls.setTexturingEnabled(false);

    gls.setBlend(true);
    gls.setCullFace(false);
    gls.clearColor(0, 1, 1, 1);
    gls.setDepthTest(false);
    gls.setDepthMask(false);

    gls.depthFunc(WebGL.LESS);
    gls.blendFuncSeparate(
      WebGL.SRC_ALPHA,
      WebGL.ONE_MINUS_SRC_ALPHA,

      WebGL.ONE,
      WebGL.ONE_MINUS_SRC_ALPHA,
    );
    gl.clear(WebGL.COLOR_BUFFER_BIT | WebGL.DEPTH_BUFFER_BIT);
    withPushedMatrix(() {
      textItems.first.drawSetup(gls, pMatrix, mvMatrix);

      for (var text in textItems) {
        text.draw(gls);
      }
      gls.bindTexture(WebGL.TEXTURE_2D, null);
    });

    requestRepaint();
  }
}
