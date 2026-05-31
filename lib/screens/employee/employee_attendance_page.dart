import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/zegar_logo.dart';

class EmployeeAttendancePage extends StatefulWidget {
  const EmployeeAttendancePage({super.key});

  @override
  State<EmployeeAttendancePage> createState() => _EmployeeAttendancePageState();
}

class _EmployeeAttendancePageState extends State<EmployeeAttendancePage>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  DateTime _now = DateTime.now();
  late final AnimationController _scan;

  static const _weekdays = [
    'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'
  ];
  static const _monthsFull = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scan.dispose();
    super.dispose();
  }

  String get _timeLabel {
    final h24 = _now.hour;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(_now.minute)}:${two(_now.second)} $ampm';
  }

  String get _dateLabel {
    final dow = _weekdays[_now.weekday - 1];
    final month = _monthsFull[_now.month - 1];
    return '$dow, $month ${_now.day}, ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _appBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                children: [
                  Text(
                    _timeLabel,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 34),
                  _scanCircle(),
                  const SizedBox(height: 18),
                  Text(
                    'Position your face within the frame',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 30),
                  _infoCards(),
                  const SizedBox(height: 24),
                  _markButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            splashRadius: 22,
          ),
          const Spacer(),
          const ZegarLogo(fontSize: 22),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none,
                color: AppColors.textPrimary),
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          const UserAvatar(
            name: MockData.employeeName,
            imageUrl: MockData.employeeAvatar,
            radius: 18,
            ring: true,
          ),
        ],
      ),
    );
  }

  Widget _scanCircle() {
    const size = 270.0;
    const inner = 150.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dark circle backdrop.
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF2A2E37), Color(0xFF14161B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          // Rotating red scan arc.
          AnimatedBuilder(
            animation: _scan,
            builder: (context, child) {
              return CustomPaint(
                size: const Size.square(size),
                painter: _ArcPainter(_scan.value * 2 * math.pi),
              );
            },
          ),
          // Inner framed face with corner brackets + scan line.
          SizedBox(
            width: inner,
            height: inner,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.network(
                    MockData.employeeAvatar,
                    width: inner,
                    height: inner,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFF2A3142),
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 60),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _scan,
                  builder: (context, child) => CustomPaint(
                    size: const Size.square(inner),
                    painter: _FramePainter(_scan.value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCards() {
    return Row(
      children: [
        Expanded(
          child: _infoCard('LOCATION', 'Main Office', withDot: false),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _infoCard('STATUS', 'On Time', withDot: true),
        ),
      ],
    );
  }

  Widget _infoCard(String label, String value, {required bool withDot}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (withDot) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _markButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.primaryLight, AppColors.primary],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Attendance marked (mock).'),
              behavior: SnackBarBehavior.floating,
            )),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.fingerprint, color: Colors.white),
          label: const Text(
            'Mark Attendance',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rotating red progress arc around the dark circle.
class _ArcPainter extends CustomPainter {
  _ArcPainter(this.rotation);
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Faint full ring.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.06),
    );

    // Bright rotating arc segment.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [Color(0x00C1121F), AppColors.primary, Color(0xFFE23744)],
        stops: [0.0, 0.7, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, rotation, math.pi * 0.55, false, arc);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.rotation != rotation;
}

/// Corner brackets + moving horizontal scan line over the face frame.
class _FramePainter extends CustomPainter {
  _FramePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.85);

    const pad = 14.0;
    const len = 22.0;
    final w = size.width;
    final h = size.height;

    void corner(Offset c, double dx, double dy) {
      canvas.drawLine(c, c.translate(dx, 0), bracket);
      canvas.drawLine(c, c.translate(0, dy), bracket);
    }

    corner(const Offset(pad, pad), len, len);
    corner(Offset(w - pad, pad), -len, len);
    corner(Offset(pad, h - pad), len, -len);
    corner(Offset(w - pad, h - pad), -len, -len);

    // Scan line sweeping up and down.
    final y = pad + (h - 2 * pad) * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
    final line = Paint()
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0),
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 1, w, 2));
    canvas.drawLine(Offset(pad, y), Offset(w - pad, y), line);
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.t != t;
}
