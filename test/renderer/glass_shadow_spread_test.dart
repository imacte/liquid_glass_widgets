import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/src/engine/rendering/glass_shadow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> raster(
      void Function(Canvas) draw, int width, int height) async {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  Future<int Function(int, int)> sample(BoxShadow shadow) async {
    // 两个独立图形用于检查扩散不会拉伸几何、移动圆心或填满间隙。
    final geometry = await raster((canvas) {
      for (final x in [20.0, 60.0]) {
        canvas.drawCircle(
            Offset(x, 20), 12, Paint()..color = const Color(0xFFFFFFFF));
      }
    }, 80, 40);
    final image = await raster((canvas) {
      canvas.scale(3);
      paintGlassShadows(
          canvas, geometry, const Rect.fromLTWH(10, 10, 80, 40), [shadow]);
    }, 300, 180);
    final bytes = (await image.toByteData())!.buffer.asUint8List();
    image.dispose();
    geometry.dispose();
    return (x, y) => bytes[(y * 300 + x) * 4 + 3];
  }

  test('subpoint spread leaves a continuous outline outside every shape',
      () async {
    final alpha = await sample(
        const BoxShadow(color: Color(0xFF000000), spreadRadius: .35));
    for (final x in [30, 70]) {
      for (final point in [
        Offset(x * 3.0, 53),
        Offset(x * 3.0, 126),
        Offset((x - 12) * 3.0 - 1, 90),
        Offset((x + 12) * 3.0, 90)
      ]) {
        expect(alpha(point.dx.toInt(), point.dy.toInt()), greaterThan(60));
      }
      expect(alpha(x * 3, 90), 0, reason: '玻璃中心不能被自身阴影染暗');
    }
    expect(alpha(150, 90), 0, reason: '保持两块玻璃之间的透明间隙');
    expect(alpha(90, 46), 0, reason: '细边不能扩散成宽灰带');
  });

  test('negative spread contracts before applying the offset', () async {
    final alpha = await sample(const BoxShadow(
        color: Color(0xFF000000), spreadRadius: -3, offset: Offset(10, 0)));
    expect(alpha(145, 90), greaterThan(100));
    expect(alpha(151, 90), 0, reason: '阴影末端应随负扩散收缩');
    expect(alpha(120, 90), 0, reason: '原几何内部始终被挖空');
  });

  test('zero spread with offset and blur still paints an exterior shadow',
      () async {
    final alpha = await sample(const BoxShadow(
        color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 3)));
    expect(alpha(90, 132), greaterThan(10));
    expect(alpha(90, 90), 0);
    expect(alpha(0, 0), 0);
  });
}
