import 'package:flutter/material.dart';

/// Points are in source image coordinates; gestures are converted from display coordinates.
class CropOverlay extends StatelessWidget {
  final Size imageSize;
  final List<Offset> quad;
  final ValueChanged<List<Offset>> onQuadChanged;
  const CropOverlay({
    super.key,
    required this.imageSize,
    required this.quad,
    required this.onQuadChanged,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final sx = constraints.maxWidth / (imageSize.width - 1);
      final sy = constraints.maxHeight / (imageSize.height - 1);
      final display = quad.map((p) => Offset(p.dx * sx, p.dy * sy)).toList();
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CropPainter(display)),
            ),
          ),
          for (var i = 0; i < 4; i++)
            Positioned(
              left: display[i].dx - 22,
              top: display[i].dy - 22,
              child: Semantics(
                label: 'Coin ${i + 1} du document',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    final next = List<Offset>.from(quad);
                    next[i] = Offset(
                      (quad[i].dx + details.delta.dx / sx).clamp(
                        0,
                        imageSize.width - 1,
                      ),
                      (quad[i].dy + details.delta.dy / sy).clamp(
                        0,
                        imageSize.height - 1,
                      ),
                    );
                    onQuadChanged(next);
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _CropPainter extends CustomPainter {
  final List<Offset> points;
  _CropPainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final polygon = Path()..addPolygon(points, true);
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addPath(polygon, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawPath(
      polygon,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) => true;
}
