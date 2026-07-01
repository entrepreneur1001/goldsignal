import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Renders [child] off-screen and captures it as a PNG.
Future<Uint8List?> captureShareCard(
  BuildContext context,
  Widget child, {
  Size size = const Size(360, 200),
}) async {
  final key = GlobalKey();
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: -size.width * 2,
      top: 0,
      child: Material(
        color: Colors.transparent,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  await Future<void>.delayed(const Duration(milliseconds: 80));

  Uint8List? bytes;
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary != null) {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = data?.buffer.asUint8List();
    }
  } finally {
    entry.remove();
  }
  return bytes;
}
