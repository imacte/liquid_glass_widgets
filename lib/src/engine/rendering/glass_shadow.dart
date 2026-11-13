// Copyright 2024-2025 Tim Lehmann for whynotmake.it
// SPDX-License-Identifier: MIT

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// 按几何遮罩绘制外阴影，中心挖空，避免玻璃再次折射自身的阴影。
void paintGlassShadows(
  Canvas canvas,
  ui.Image geometry,
  Rect bounds,
  List<BoxShadow> shadows,
) {
  final source = Rect.fromLTWH(
    0,
    0,
    geometry.width.toDouble(),
    geometry.height.toDouble(),
  );
  for (final shadow in shadows) {
    if (shadow.color.a == 0) continue;
    final clip = bounds.shift(shadow.offset).inflate(
          shadow.spreadRadius.abs() + shadow.blurRadius * 3,
        );
    canvas.saveLayer(clip, Paint());
    final blur = ui.ImageFilter.blur(
      sigmaX: shadow.blurSigma,
      sigmaY: shadow.blurSigma,
      tileMode: ui.TileMode.decal,
    );
    // 扩散必须作用于遮罩，而不是仅扩大裁切框或拉伸整张图。
    // 先膨胀/腐蚀，再模糊；多块玻璃仍保持各自的位置与间隙。
    final spread = shadow.spreadRadius;
    final expansion = spread > 0
        ? ui.ImageFilter.dilate(radiusX: spread, radiusY: spread)
        : spread < 0
            ? ui.ImageFilter.erode(radiusX: -spread, radiusY: -spread)
            : null;
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(shadow.color, BlendMode.srcIn)
      ..imageFilter = expansion == null
          ? blur
          : ui.ImageFilter.compose(outer: blur, inner: expansion);
    canvas.drawImageRect(geometry, source, bounds.shift(shadow.offset), paint);
    canvas.drawImageRect(
      geometry,
      source,
      bounds,
      Paint()..blendMode = BlendMode.dstOut,
    );
    canvas.restore();
  }
}
