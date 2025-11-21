import 'package:flutter/material.dart';
import 'dart:math';

class RadarPainter extends CustomPainter {
  final double progress;
  final bool isScanning;

  RadarPainter({required this.progress, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circles
    final circlePaint = Paint()
      ..color = const Color(0xFF6366f1).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, circlePaint);
    }

    // Draw WiFi icon in center
    final iconPaint = Paint()
      ..color = const Color(0xFF6366f1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 40, iconPaint);

    // Draw scanning arc
    if (isScanning) {
      final scanPaint = Paint()
        ..color = const Color(0xFF6366f1).withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final sweepAngle = pi / 3;
      final startAngle = progress * 2 * pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isScanning != isScanning;
  }
}

class BluetoothRadarPainter extends CustomPainter {
  final double progress;
  final bool isScanning;

  BluetoothRadarPainter({required this.progress, required this.isScanning});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final circlePaint = Paint()
      ..color = const Color(0xFF6366f1).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * i / 3, circlePaint);
    }

    final iconPaint = Paint()
      ..color = const Color(0xFF6366f1)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 40, iconPaint);

    if (isScanning) {
      final scanPaint = Paint()
        ..color = const Color(0xFF6366f1).withOpacity(0.3)
        ..style = PaintingStyle.fill;

      final sweepAngle = pi / 4;
      final startAngle = progress * 2 * pi;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(BluetoothRadarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isScanning != isScanning;
  }
}