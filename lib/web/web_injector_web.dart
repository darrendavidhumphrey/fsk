// lib/web_injector_web.dart
import 'dart:html' as html;

void injectWebCSS() {
  final html.StyleElement styleElement = html.StyleElement();
  styleElement.text = '''
    flt-platform-view-slot > canvas {
      width: 100% !important;
      height: 100% !important;
      max-width: 100% !important;
      max-height: 100% !important;
      position: relative !important;
    }
  ''';
  html.document.head?.append(styleElement);
}
