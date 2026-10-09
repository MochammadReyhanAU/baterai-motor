import 'dart:math';

import 'package:flutter/material.dart';

import '../../logic/insights.dart';
import '../theme.dart';

/// Ilustrasi motor listrik (desain orisinal) yang bereaksi terhadap status:
/// roda berputar saat jalan, lampu menyala saat motor hidup, kabel cas
/// berdenyut saat dicas, dan isi baterai di badan motor mengikuti persentase.
class MotorScene extends StatefulWidget {
  const MotorScene({
    super.key,
    required this.state,
    required this.soc,
    required this.bodyColor,
    this.height = 190,
  });

  final MotorState state;
  final int soc;
  final Color bodyColor;
  final double height;

  @override
  State<MotorScene> createState() => _MotorSceneState();
}

class _MotorSceneState extends State<MotorScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  bool get _animated => widget.state == MotorState.riding || widget.state == MotorState.charging;

  @override
  void initState() {
    super.initState();
    if (_animated) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant MotorScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animated && !_c.isAnimating) {
      _c.repeat();
    } else if (!_animated && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _MotorPainter(
            t: _c.value,
            state: widget.state,
            soc: widget.soc,
            body: widget.bodyColor,
          ),
        ),
      ),
    );
  }
}

class _MotorPainter extends CustomPainter {
  _MotorPainter({required this.t, required this.state, required this.soc, required this.body});

  final double t;
  final MotorState state;
  final int soc;
  final Color body;

  // Gambar dibuat di kotak 320 x 180 lalu diskalakan.
  static const _w = 320.0;
  static const _h = 180.0;

  bool get _riding => state == MotorState.riding;
  bool get _charging => state == MotorState.charging;
  bool get _on => state == MotorState.riding || state == MotorState.standby;
  bool get _offline => state == MotorState.offline;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / _w, size.height / _h);
    canvas.save();
    canvas.translate((size.width - _w * s) / 2, (size.height - _h * s) / 2);
    canvas.scale(s);
    canvas.clipRect(const Rect.fromLTWH(0, 0, _w, _h));

    final bounce = _riding ? sin(t * pi * 8) * 0.8 : 0.0;
    const groundY = 160.0;
    const rear = Offset(78, 128);
    const front = Offset(246, 128);
    const r = 31.0;

    _ground(canvas, groundY);
    if (_riding) _speedLines(canvas);

    // Bayangan
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(162, groundY), width: 230, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    final wheelAngle = _riding ? t * pi * 2 * 4 : 0.0;
    _wheel(canvas, rear, r, wheelAngle);
    _wheel(canvas, front, r, wheelAngle);

    canvas.save();
    canvas.translate(0, bounce);
    _frame(canvas, rear, front);
    canvas.restore();

    if (state == MotorState.parked || _offline) _stand(canvas, groundY);
    if (_charging) _chargeCable(canvas, groundY);
    canvas.restore();
  }

  void _ground(Canvas c, double y) {
    final p = Paint()
      ..shader = const LinearGradient(colors: [Colors.transparent, AppColors.line, Colors.transparent])
          .createShader(const Rect.fromLTWH(0, 0, _w, 2))
      ..strokeWidth = 2;
    c.drawLine(Offset(0, y), Offset(_w, y), p);
    if (_riding) {
      // Garis jalan bergerak
      final dash = Paint()
        ..color = AppColors.line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 6; i++) {
        final x = ((i * 64) - t * 64 * 4) % (_w + 64) - 32;
        c.drawLine(Offset(x, y + 10), Offset(x + 26, y + 10), dash);
      }
    }
  }

  void _speedLines(Canvas c) {
    final p = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    for (var i = 0; i < 4; i++) {
      final phase = (t * 3 + i * 0.27) % 1.0;
      final y = 70.0 + i * 16;
      final x = 40 - phase * 40;
      p.color = AppColors.good.withValues(alpha: 0.5 * (1 - phase));
      c.drawLine(Offset(x, y), Offset(x - 22 - i * 4, y), p);
    }
  }

  void _chargeCable(Canvas c, double groundY) {
    // Kabel dari port di bawah jok ke stop kontak di kiri.
    // Port cas di bawah jok, kabel menjuntai ke stop kontak di kiri.
    final path = Path()
      ..moveTo(100, 98)
      ..cubicTo(92, 150, 50, 168, 30, groundY - 18);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    // Pulsa listrik bergerak sepanjang kabel menuju motor.
    final metric = path.computeMetrics().first;
    for (var i = 0; i < 3; i++) {
      final f = 1 - ((t + i / 3) % 1.0);
      final pos = metric.getTangentForOffset(metric.length * f)!.position;
      c.drawCircle(pos, 3.2, Paint()..color = AppColors.caution);
      c.drawCircle(pos, 7, Paint()..color = AppColors.caution.withValues(alpha: 0.18));
    }
    // Stop kontak
    c.drawCircle(const Offset(100, 98), 4, Paint()..color = AppColors.caution);
    final plug = RRect.fromRectAndRadius(Rect.fromLTWH(8, groundY - 30, 22, 26), const Radius.circular(5));
    c.drawRRect(plug, Paint()..color = const Color(0xFF1E293B));
    c.drawRRect(plug, Paint()
      ..color = AppColors.caution
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    final bolt = Path()
      ..moveTo(21, groundY - 26)
      ..lineTo(14, groundY - 15)
      ..lineTo(19, groundY - 15)
      ..lineTo(16, groundY - 7)
      ..lineTo(24, groundY - 19)
      ..lineTo(19, groundY - 19)
      ..close();
    c.drawPath(bolt, Paint()..color = AppColors.caution);
  }

  void _wheel(Canvas c, Offset o, double r, double angle) {
    c.drawCircle(o, r, Paint()..color = const Color(0xFF0F172A));
    c.drawCircle(
        o,
        r - 4,
        Paint()
          ..color = const Color(0xFF1F2937)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8);
    c.drawCircle(
        o,
        r - 9,
        Paint()
          ..color = const Color(0xFF64748B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final spoke = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = angle + i * 2 * pi / 5;
      c.drawLine(o + Offset(cos(a), sin(a)) * 7, o + Offset(cos(a), sin(a)) * (r - 10), spoke);
    }
    c.drawCircle(o, 7, Paint()..color = const Color(0xFFCBD5E1));
    c.drawCircle(o, 3, Paint()..color = const Color(0xFF334155));
    // Cakram rem
    c.drawCircle(
        o,
        13,
        Paint()
          ..color = const Color(0xFF94A3B8).withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  void _frame(Canvas c, Offset rear, Offset front) {
    final dark = const Color(0xFF0F172A);
    final bodyPaint = Paint()..color = _offline ? body.withValues(alpha: 0.45) : body;

    // Swing arm
    c.drawLine(rear, const Offset(140, 120), Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round);
    // Garpu depan
    c.drawLine(const Offset(214, 58), front, Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);

    // Spakbor belakang
    c.drawArc(Rect.fromCircle(center: rear, radius: 38), pi * 1.08, pi * 0.62, false, Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);
    // Spakbor depan
    c.drawArc(Rect.fromCircle(center: front, radius: 37), pi * 1.15, pi * 0.55, false, Paint()
      ..color = bodyPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round);

    // Badan utama
    final bodyPath = Path()
      ..moveTo(62, 84)
      ..lineTo(84, 76)
      ..lineTo(118, 74)
      ..quadraticBezierTo(150, 74, 168, 64)
      ..lineTo(198, 52)
      ..quadraticBezierTo(214, 48, 220, 60)
      ..lineTo(206, 82)
      ..quadraticBezierTo(196, 116, 166, 122)
      ..lineTo(126, 122)
      ..quadraticBezierTo(112, 122, 106, 108)
      ..lineTo(98, 96)
      ..lineTo(70, 96)
      ..quadraticBezierTo(60, 94, 62, 84)
      ..close();
    c.drawPath(bodyPath, bodyPaint);
    // Kilap
    c.drawPath(
      Path()
        ..moveTo(86, 80)
        ..lineTo(118, 78)
        ..quadraticBezierTo(150, 78, 170, 68)
        ..lineTo(198, 57),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Jok
    final seat = Path()
      ..moveTo(84, 74)
      ..quadraticBezierTo(90, 62, 110, 62)
      ..lineTo(160, 62)
      ..quadraticBezierTo(168, 62, 166, 68)
      ..quadraticBezierTo(150, 74, 118, 74)
      ..close();
    c.drawPath(seat, Paint()..color = dark);

    // Stang
    c.drawLine(const Offset(210, 52), const Offset(200, 36), Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    c.drawLine(const Offset(194, 34), const Offset(206, 36), Paint()
      ..color = dark
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);

    // Lampu depan + sorot
    const head = Offset(222, 66);
    if (_on) {
      final beam = Path()
        ..moveTo(head.dx, head.dy - 5)
        ..lineTo(_w, head.dy - 22)
        ..lineTo(_w, head.dy + 26)
        ..lineTo(head.dx, head.dy + 5)
        ..close();
      c.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(colors: [
            const Color(0xFFFFF7CC).withValues(alpha: 0.55),
            const Color(0xFFFFF7CC).withValues(alpha: 0),
          ]).createShader(const Rect.fromLTWH(222, 40, 98, 60)),
      );
    }
    c.drawCircle(head, 6.5, Paint()..color = _on ? const Color(0xFFFFF7CC) : const Color(0xFF475569));
    // Lampu belakang
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(58, 82, 8, 7), const Radius.circular(2)),
      Paint()..color = _on ? const Color(0xFFEF4444) : const Color(0xFF7F1D1D),
    );

    // Baterai di badan motor (isi mengikuti SOC)
    final pack = RRect.fromRectAndRadius(const Rect.fromLTWH(128, 86, 58, 26), const Radius.circular(6));
    c.drawRRect(pack, Paint()..color = const Color(0xFF0B1220));
    final fillW = 52 * (soc.clamp(0, 100) / 100);
    final fillColor = _offline ? const Color(0xFF475569) : Insights.socColor(soc);
    double glow = 1;
    if (_charging) glow = 0.6 + 0.4 * (0.5 + 0.5 * sin(t * pi * 2));
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(131, 89, fillW, 20), const Radius.circular(4)),
      Paint()..color = fillColor.withValues(alpha: glow),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(186, 94, 4, 10), const Radius.circular(1.5)),
      Paint()..color = const Color(0xFF0B1220),
    );
    if (_charging) {
      final b = Path()
        ..moveTo(160, 90)
        ..lineTo(152, 100)
        ..lineTo(158, 100)
        ..lineTo(154, 108)
        ..lineTo(164, 97)
        ..lineTo(158, 97)
        ..close();
      c.drawPath(b, Paint()..color = Colors.white);
    }
    if (state == MotorState.powerCut) {
      final x = Paint()
        ..color = AppColors.bad
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(146, 90), const Offset(168, 108), x);
      c.drawLine(const Offset(168, 90), const Offset(146, 108), x);
    }
  }

  void _stand(Canvas c, double groundY) {
    c.drawLine(const Offset(132, 118), Offset(120, groundY - 1), Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _MotorPainter old) =>
      old.t != t || old.state != state || old.soc != soc || old.body != body;
}
