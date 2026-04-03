// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';

void registerWebIframe(String viewId, String html_content) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..srcdoc = html_content
      ..setAttribute('sandbox',
          'allow-scripts allow-same-origin allow-popups allow-forms');
    return iframe;
  });
}

Widget buildWebIframeMap(String htmlContent, String viewId) {
  return HtmlElementView(viewType: viewId);
}
