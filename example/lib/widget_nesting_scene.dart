import 'package:flutter/material.dart';
import 'package:fsk/fsk.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'dart:math' as math;

class WidgetNestingScene extends FskScene {
  WidgetNestingScene({super.navigationDelegate})
    : super(clearColor: const Color(0xFF1A1A2A));

  final TextEditingController _textController = TextEditingController(
    text: "100.0",
  );
  final FocusNode _focusNode = FocusNode();

  @override
  Future<void> onInit() async {
    await super.onInit();
    skinSize = const Size(1920, 1080);
    useBoxFitLayout = false; // Use pure world coordinates for OrbitView

    if (navigationDelegate is OrbitViewDelegate) {
      (navigationDelegate as OrbitViewDelegate).setViewDistance(800);
    }

    // 1. Create the main scene group
    final mainGroup = FskGroup("main_group", this);
    mainGroup.position = vm.Vector3.zero();
    addNode(mainGroup);

    final rotatingGroup = FskGroup("rotating_group", this);
    mainGroup.addNode(rotatingGroup);

    // Background
    final bgQuad = FskQuad(
      "bg",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3.zero(), const Size(800, 400)),
      const Rect.fromLTWH(0, 0, 1, 1),
      modulateColor: Colors.blueGrey.withValues(alpha: 0.3),
    );
    bgQuad.isPickable = false;
    rotatingGroup.addNode(bgQuad);

    // 2. Status/Display Texts (Flutter Text)
    final liveDisplay = FskFlutterText(
      "live_display",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 200, 0), const Size(800, 60)),
      text: "Live: 100.0",
      textColor: Colors.white,
      style: const TextStyle(fontFamily: 'isocpeur', fontSize: 60),
    );
    mainGroup.addNode(liveDisplay);

    final submittedDisplay = FskFlutterText(
      "submitted_display",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 280, 0), const Size(800, 60)),
      text: "Submitted: 100.0",
      textColor: Colors.greenAccent,
      style: const TextStyle(fontFamily: 'isocpeur', fontSize: 60),
    );
    mainGroup.addNode(submittedDisplay);

    _initInputWidget(
      rotatingGroup,
      liveDisplay: liveDisplay,
      submittedDisplay: submittedDisplay,
    );
  }

  void _initInputWidget(
    FskGroup rotatingGroup, {
    FskFlutterText? liveDisplay,
    FskFlutterText? submittedDisplay,
  }) {
    // 3. The Interactive Input Widget (Editable Flutter Text)
    final editableText = FskEditableFlutterText(
      "editable_text",
      this,
      ReferenceBox.fromCenterSize(vm.Vector3(0, 0, 20), const Size(600, 150)),
      text: _textController.text,
      style: const TextStyle(
        fontFamily: 'isocpeur',
        fontSize: 40,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      onValidate: (val) {
        final d = double.tryParse(val);
        if (d == null && val.isNotEmpty) {
          return "Invalid Double Number!";
        }
        return null;
      },
      onSubmitted: (val) {
        Logging.logInfo("WidgetNestingScene: onSubmitted received '$val'", source: "WidgetNestingScene");
        if (submittedDisplay != null) {
          submittedDisplay.text = "Submitted: $val";
        }
      },
      widgetSize: const Size(600, 150),
    );

    rotatingGroup.addNode(editableText);

    // Sync live display
    editableText.controller.addListener(() {
      final text = editableText.controller.text;
      if (liveDisplay != null) {
        liveDisplay.text = "Live: $text";
      }
    });
  }

  @override
  void updateAnimations(DateTime now) {
    super.updateAnimations(now);
    final rotatingGroup = findNode<FskGroup>("rotating_group");
    if (rotatingGroup != null) {
      final t = currentTime;
      rotatingGroup.rotation = vm.Vector3(0.3 * math.sin(t * 0.5), t * 0.2, 0);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
