import 'dart:math';
import 'package:flutter/material.dart';
import 'models.dart';
import 'theme_data.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Shared data bundle passed to every concept widget.
// ═══════════════════════════════════════════════════════════════════════════════
class DashboardData {
  final Status? status;
  final bool connected;
  final bool txLost;
  final String ugMotorName;
  final String ohMotorName;
  final bool ugBuzzer;
  final bool ohBuzzer;
  final VoidCallback onUgOn;
  final VoidCallback onUgOff;
  final VoidCallback onOhOn;
  final VoidCallback onOhOff;

  const DashboardData({
    required this.status,
    required this.connected,
    required this.txLost,
    required this.ugMotorName,
    required this.ohMotorName,
    required this.ugBuzzer,
    required this.ohBuzzer,
    required this.onUgOn,
    required this.onUgOff,
    required this.onOhOn,
    required this.onOhOff,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept A — Water-fill gauges · side-by-side tanks · separate motor cards
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptADashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptADashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      // Tank cards side by side
      Row(children: [
        Expanded(child: _WaterFillTankCard(
          label: 'Underground',
          state: s?.ugState ?? '',
          showLora: false,
          loraOk: true,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _WaterFillTankCard(
          label: 'Overhead',
          state: s?.ohState ?? '',
          showLora: true,
          loraOk: s?.loraOk ?? true,
          context: context,
        )),
      ]),
      const SizedBox(height: 10),
      _MotorControlCard(
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        context: context,
      ),
      const SizedBox(height: 10),
      _MotorControlCard(
        motorName: d.ohMotorName,
        motorOn: s?.ohMotor ?? false,
        buzzer: d.ohBuzzer,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        context: context,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept B — Arc gauges · LoRa lost banner · buzzer
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptBDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptBDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      if (s?.txLost == true)
        _LostBanner(lastKnown: s?.ohLastKnown ?? '', context: context),
      if (s?.txLost == true) const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _ArcTankCard(
          label: 'Underground',
          state: s?.ugState ?? '',
          showLora: false,
          loraOk: true,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ArcTankCard(
          label: 'Overhead',
          state: s?.ohState ?? '',
          showLora: true,
          loraOk: s?.loraOk ?? true,
          context: context,
        )),
      ]),
      const SizedBox(height: 10),
      _MotorControlCard(
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        context: context,
      ),
      const SizedBox(height: 10),
      _MotorControlCard(
        motorName: d.ohMotorName,
        motorOn: s?.ohMotor ?? false,
        buzzer: d.ohBuzzer,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        context: context,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept C — Compact horizontal cards (arc gauge + motor inline)
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptCDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptCDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      _HorizontalTankCard(
        label: 'Underground',
        state: s?.ugState ?? '',
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        showLora: false,
        loraOk: true,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        context: context,
      ),
      const SizedBox(height: 10),
      _HorizontalTankCard(
        label: 'Overhead',
        state: s?.ohState ?? '',
        motorName: d.ohMotorName,
        motorOn: s?.ohMotor ?? false,
        buzzer: d.ohBuzzer,
        showLora: true,
        loraOk: s?.loraOk ?? true,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        context: context,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept D — 2-col 3-row grid: tanks / motor status / motor controls
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptDDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptDDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      // Row 1: tank gauges
      Row(children: [
        Expanded(child: _SemiCircleTankCard(
          label: 'Underground',
          state: s?.ugState ?? '',
          showLora: false,
          loraOk: true,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _SemiCircleTankCard(
          label: 'Overhead',
          state: s?.ohState ?? '',
          showLora: true,
          loraOk: s?.loraOk ?? true,
          context: context,
        )),
      ]),
      const SizedBox(height: 10),
      // Row 2: motor status
      Row(children: [
        Expanded(child: _GridMotorStatus(
          motorName: d.ugMotorName,
          motorOn: s?.ugMotor ?? false,
          buzzer: d.ugBuzzer,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _GridMotorStatus(
          motorName: d.ohMotorName,
          motorOn: s?.ohMotor ?? false,
          buzzer: d.ohBuzzer,
          context: context,
        )),
      ]),
      const SizedBox(height: 10),
      // Row 3: motor controls
      Row(children: [
        Expanded(child: _GridMotorButton(
          motorOn: s?.ugMotor ?? false,
          buzzer: d.ugBuzzer,
          onOn: d.onUgOn,
          onOff: d.onUgOff,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _GridMotorButton(
          motorOn: s?.ohMotor ?? false,
          buzzer: d.ohBuzzer,
          onOn: d.onOhOn,
          onOff: d.onOhOff,
          context: context,
        )),
      ]),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept E — Pill cards: tank + motor + button in one streamlined row
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptEDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptEDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      _PillCard(
        label: 'Overhead',
        state: s?.ohState ?? '',
        motorName: d.ohMotorName,
        motorOn: s?.ohMotor ?? false,
        buzzer: d.ohBuzzer,
        showLora: true,
        loraOk: s?.loraOk ?? true,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        context: context,
      ),
      const SizedBox(height: 10),
      _PillCard(
        label: 'Underground',
        state: s?.ugState ?? '',
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        showLora: false,
        loraOk: true,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        context: context,
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept F — Hybrid: B's arc gauges + D's 2-col motor grid (DEFAULT)
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptFDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptFDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      if (s?.txLost == true)
        _LostBanner(lastKnown: s?.ohLastKnown ?? '', context: context),
      if (s?.txLost == true) const SizedBox(height: 10),
      // Row 1: Arc gauges
      Row(children: [
        Expanded(child: _ArcTankCard(
          label: 'Underground',
          state: s?.ugState ?? '',
          showLora: false,
          loraOk: true,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _ArcTankCard(
          label: 'Overhead',
          state: s?.ohState ?? '',
          showLora: true,
          loraOk: s?.loraOk ?? true,
          context: context,
        )),
      ]),
      const SizedBox(height: 10),
      // Row 2: motor status grid
      Row(children: [
        Expanded(child: _GridMotorStatus(
          motorName: d.ugMotorName,
          motorOn: s?.ugMotor ?? false,
          buzzer: d.ugBuzzer,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _GridMotorStatus(
          motorName: d.ohMotorName,
          motorOn: s?.ohMotor ?? false,
          buzzer: d.ohBuzzer,
          context: context,
        )),
      ]),
      const SizedBox(height: 10),
      // Row 3: motor control buttons
      Row(children: [
        Expanded(child: _GridMotorButton(
          motorOn: s?.ugMotor ?? false,
          buzzer: d.ugBuzzer,
          onOn: d.onUgOn,
          onOff: d.onUgOff,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _GridMotorButton(
          motorOn: s?.ohMotor ?? false,
          buzzer: d.ohBuzzer,
          onOn: d.onOhOn,
          onOff: d.onOhOff,
          context: context,
        )),
      ]),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED BUILDING BLOCKS
// ═══════════════════════════════════════════════════════════════════════════════

// ─── State → colour / percentage / label ─────────────────────────────────────
Color _stateColor(String state, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (state) {
    case 'FULL':  return isDark ? kBlue : kLightBlue;
    case 'HALF':  return isDark ? kGreen : kLightBlue;
    case 'LOW':   return isDark ? kOrange : kLightOrange;
    case 'EMPTY': return isDark ? kRed : kLightRed;
    default:      return const Color(0xFF8c8c8c);
  }
}

double _statePct(String state) {
  switch (state) {
    case 'FULL':  return 1.0;
    case 'HALF':  return 0.5;
    case 'LOW':   return 0.2;
    case 'EMPTY': return 0.0;
    default:      return 0.0;
  }
}

String _stateLabel(String state) {
  if (state == 'FULL' || state == 'HALF' || state == 'LOW' || state == 'EMPTY') {
    return state;
  }
  return state.isNotEmpty ? '?' : '--';
}

Color _waterBlue(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF29b6f6)
        : const Color(0xFF0288d1);

// ─── Water fill circle (Concepts A, D) ───────────────────────────────────────
class _WaterFillCircle extends StatefulWidget {
  final String state;
  final double size;
  const _WaterFillCircle(this.state, {this.size = 120});

  @override
  State<_WaterFillCircle> createState() => _WaterFillCircleState();
}

class _WaterFillCircleState extends State<_WaterFillCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct   = _statePct(widget.state);
    final color = _stateColor(widget.state, context);
    final label = _stateLabel(widget.state);
    final waterBlue = _waterBlue(context);

    return SizedBox(
      width: widget.size, height: widget.size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 4),
        ),
        child: ClipOval(
          child: Stack(
            children: [
              // Water fill
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: pct > 0 ? (0.15 + 0.85 * pct) : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          waterBlue.withOpacity(pct >= 1.0 ? 0.5 : 0.35),
                          waterBlue.withOpacity(pct >= 1.0 ? 0.25 : 0.08),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Animated wave at the water surface
              if (pct > 0)
                AnimatedBuilder(
                  animation: _waveCtrl,
                  builder: (_, __) {
                    final fillH = pct > 0 ? (0.15 + 0.85 * pct) : 0.0;
                    final waterTop = 1.0 - fillH;
                    // Clamp so wave is visible even when full
                    final topPos = (widget.size * waterTop - 6).clamp(2.0, widget.size - 14);
                    return Positioned(
                      top: topPos,
                      left: -widget.size * 0.1,
                      right: -widget.size * 0.1,
                      height: 14,
                      child: CustomPaint(
                        painter: _WavePainter(
                          phase: _waveCtrl.value * 2 * pi,
                          color: waterBlue.withOpacity(0.5),
                        ),
                      ),
                    );
                  },
                ),
              // Label
              Center(
                child: Text(label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 1,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Color(0x80000000)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws an animated sine wave for the water surface.
class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  const _WavePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height * 0.5 +
          sin((x / size.width) * 2 * pi + phase) * 3 +
          sin((x / size.width) * 4 * pi + phase * 1.5) * 1.5;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}

// ─── Arc gauge circle (Concepts B, C, F) ─────────────────────────────────────
class _ArcGaugeCircle extends StatelessWidget {
  final String state;
  final double size;
  const _ArcGaugeCircle(this.state, {this.size = 120});

  @override
  Widget build(BuildContext context) {
    final pct   = _statePct(state);
    final color = _stateColor(state, context);
    final label = _stateLabel(state);

    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _ArcPainter(pct: pct, color: color, trackColor: cardBd(context)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (pct > 0)
                Text('~${(pct * 100).toInt()}%',
                  style: TextStyle(color: labelColor(context), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double pct;
  final Color color;
  final Color trackColor;
  const _ArcPainter({required this.pct, required this.color, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    canvas.drawArc(rect, 0, 2 * pi, false,
      Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);

    if (pct > 0) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * pct, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.pct != pct || old.color != color;
}

// ─── AntD semi-circle gauge (Concept D) ──────────────────────────────────────
/// Eye-comfort green for Aqua Grid FULL state.
const _comfortGreen = Color(0xFF52c41a);

Color _antdStateColor(String state) {
  switch (state) {
    case 'FULL':  return _comfortGreen;
    case 'HALF':  return kBlue;
    case 'LOW':   return kOrange;
    case 'EMPTY': return kRed;
    default:      return const Color(0xFF8c8c8c);
  }
}

class _SemiCircleGauge extends StatelessWidget {
  final String state;
  final double size;
  const _SemiCircleGauge(this.state, {this.size = 110});

  @override
  Widget build(BuildContext context) {
    final pct = _statePct(state);
    final color = _antdStateColor(state);
    final label = _stateLabel(state);

    return SizedBox(
      width: size,
      height: size * 0.62,
      child: CustomPaint(
        painter: _SemiCirclePainter(
          pct: pct,
          color: color,
          trackColor: cardBd(context),
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: Align(
          alignment: const Alignment(0, 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.8,
                ),
              ),
              if (pct > 0)
                Text('${(pct * 100).toInt()}%',
                  style: TextStyle(color: labelColor(context), fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SemiCirclePainter extends CustomPainter {
  final double pct;
  final Color color;
  final Color trackColor;
  final bool isDark;
  const _SemiCirclePainter({
    required this.pct, required this.color,
    required this.trackColor, required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 4;
    final r  = size.width / 2 - 8;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const strokeW = 10.0;

    // Track (subtle)
    canvas.drawArc(rect, pi, pi, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round);

    // Filled arc with 3D gradient
    if (pct > 0) {
      final sweepAngle = pi * pct;
      final gradient = SweepGradient(
        startAngle: pi,
        endAngle: pi + sweepAngle,
        colors: [
          color.withOpacity(0.5),
          color,
          Color.lerp(color, Colors.white, 0.25)!,
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      canvas.drawArc(rect, pi, sweepAngle, false,
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round);

      // Glow effect behind the arc
      canvas.drawArc(rect, pi, sweepAngle, false,
        Paint()
          ..color = color.withOpacity(0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

      // Bright dot at the tip
      final tipAngle = pi + sweepAngle;
      final tipX = cx + r * cos(tipAngle);
      final tipY = cy + r * sin(tipAngle);
      canvas.drawCircle(Offset(tipX, tipY), 5,
        Paint()..color = color);
      canvas.drawCircle(Offset(tipX, tipY), 3,
        Paint()..color = isDark ? Colors.white : Colors.white);
      // Outer glow on tip
      canvas.drawCircle(Offset(tipX, tipY), 8,
        Paint()
          ..color = color.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }

    // Scale ticks
    for (int i = 0; i <= 4; i++) {
      final angle = pi + (pi * i / 4);
      final outerR = r + 6;
      final innerR = r + 2;
      final ox = cx + outerR * cos(angle);
      final oy = cy + outerR * sin(angle);
      final ix = cx + innerR * cos(angle);
      final iy = cy + innerR * sin(angle);
      canvas.drawLine(Offset(ix, iy), Offset(ox, oy),
        Paint()
          ..color = trackColor
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_SemiCirclePainter old) =>
      old.pct != pct || old.color != color;
}

// ─── Semi-circle tank card (D) ───────────────────────────────────────────────
class _SemiCircleTankCard extends StatelessWidget {
  final String label;
  final String state;
  final bool showLora;
  final bool loraOk;
  final BuildContext context;

  const _SemiCircleTankCard({
    required this.label, required this.state,
    required this.showLora, required this.loraOk,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
              style: TextStyle(color: labelColor(context), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            if (showLora) _LoraBadge(loraOk: loraOk),
          ],
        ),
        const SizedBox(height: 10),
        _SemiCircleGauge(state),
      ]),
    );
  }
}

// ─── LoRa badge ──────────────────────────────────────────────────────────────
class _LoraBadge extends StatefulWidget {
  final bool loraOk;
  const _LoraBadge({required this.loraOk});

  @override
  State<_LoraBadge> createState() => _LoraBadgeState();
}

class _LoraBadgeState extends State<_LoraBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (!widget.loraOk) _blinkCtrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LoraBadge old) {
    super.didUpdateWidget(old);
    if (widget.loraOk != old.loraOk) {
      if (!widget.loraOk) {
        _blinkCtrl.repeat(reverse: true);
      } else {
        _blinkCtrl.stop();
        _blinkCtrl.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.loraOk ? kBlue : kRed;
    final bg    = widget.loraOk ? kBlue.withOpacity(0.12) : kRed.withOpacity(0.15);
    final icon  = widget.loraOk ? Icons.wifi : Icons.wifi_off;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text('LoRa', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    );

    if (!widget.loraOk) {
      return FadeTransition(
        opacity: _blinkCtrl.drive(Tween(begin: 0.3, end: 1.0)),
        child: badge,
      );
    }
    return badge;
  }
}

// ─── Transmitter lost banner ─────────────────────────────────────────────────
class _LostBanner extends StatelessWidget {
  final String lastKnown;
  final BuildContext context;
  const _LostBanner({required this.lastKnown, required this.context});

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.1),
        border: Border.all(color: kRed.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: kRed, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'OH Transmitter lost${lastKnown.isNotEmpty ? ' — last: $lastKnown' : ''}',
            style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ─── Motor status pill ───────────────────────────────────────────────────────
class _MotorPill extends StatelessWidget {
  final bool on;
  const _MotorPill(this.on);

  @override
  Widget build(BuildContext context) {
    final clr = on ? accentGreen(context) : accentRed(context);
    final bg  = clr.withOpacity(0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: clr.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('● ${on ? "ON" : "OFF"}',
        style: TextStyle(color: clr, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Water fill tank card (A, D) ─────────────────────────────────────────────
class _WaterFillTankCard extends StatelessWidget {
  final String label;
  final String state;
  final bool showLora;
  final bool loraOk;
  final BuildContext context;

  const _WaterFillTankCard({
    required this.label, required this.state,
    required this.showLora, required this.loraOk,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
              style: TextStyle(color: labelColor(context), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            if (showLora) _LoraBadge(loraOk: loraOk),
          ],
        ),
        const SizedBox(height: 16),
        _WaterFillCircle(state, size: 140),
        const SizedBox(height: 10),
      ]),
    );
  }
}

// ─── Arc gauge tank card (B, F) ──────────────────────────────────────────────
class _ArcTankCard extends StatelessWidget {
  final String label;
  final String state;
  final bool showLora;
  final bool loraOk;
  final BuildContext context;

  const _ArcTankCard({
    required this.label, required this.state,
    required this.showLora, required this.loraOk,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
              style: TextStyle(color: labelColor(context), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            if (showLora) _LoraBadge(loraOk: loraOk),
          ],
        ),
        const SizedBox(height: 12),
        _ArcGaugeCircle(state, size: 140),
        const SizedBox(height: 10),
      ]),
    );
  }
}

// ─── Motor control card (A, B) ───────────────────────────────────────────────
class _MotorControlCard extends StatelessWidget {
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _MotorControlCard({
    required this.motorName, required this.motorOn, required this.buzzer,
    required this.onOn, required this.onOff, required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final greenC = accentGreen(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        // Animated gear icon
        _GearIcon(motorOn: motorOn, buzzer: buzzer),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(motorName, style: TextStyle(color: textColor(context), fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: motorOn ? greenC : labelColor(context),
                  boxShadow: motorOn ? [BoxShadow(color: greenC.withOpacity(0.5), blurRadius: 6)] : null,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                motorOn ? 'Running' : 'Stopped',
                style: TextStyle(color: labelColor(context), fontSize: 11),
              ),
              if (buzzer) ...[
                const SizedBox(width: 6),
                Icon(Icons.notifications_active, color: kOrange, size: 14),
              ],
            ]),
          ],
        )),
        _PowerButton(motorOn: motorOn, onOn: onOn, onOff: onOff, buzzer: buzzer),
      ]),
    );
  }
}

// ─── Grid motor status card (D, F) ──────────────────────────────────────────
class _GridMotorStatus extends StatelessWidget {
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final BuildContext context;

  const _GridMotorStatus({
    required this.motorName, required this.motorOn,
    required this.buzzer, required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final greenC = accentGreen(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GearIcon(motorOn: motorOn, buzzer: buzzer, size: 40),
          const SizedBox(height: 8),
          Text(motorName, style: TextStyle(color: textColor(context), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: motorOn ? greenC : labelColor(context),
                boxShadow: motorOn ? [BoxShadow(color: greenC.withOpacity(0.5), blurRadius: 6)] : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              motorOn ? 'Running' : 'Stopped',
              style: TextStyle(color: labelColor(context), fontSize: 11),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─── Grid motor button (D, F) ────────────────────────────────────────────────
class _GridMotorButton extends StatelessWidget {
  final bool motorOn;
  final bool buzzer;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _GridMotorButton({
    required this.motorOn, required this.onOn,
    required this.onOff, required this.context,
    this.buzzer = false,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _PowerButton(motorOn: motorOn, onOn: onOn, onOff: onOff, buzzer: buzzer, expanded: true),
    );
  }
}

// ─── Horizontal tank card (C) ────────────────────────────────────────────────
class _HorizontalTankCard extends StatelessWidget {
  final String label;
  final String state;
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final bool showLora;
  final bool loraOk;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _HorizontalTankCard({
    required this.label, required this.state,
    required this.motorName, required this.motorOn,
    required this.buzzer, required this.showLora,
    required this.loraOk, required this.onOn,
    required this.onOff, required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        _ArcGaugeCircle(state, size: 80),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: TextStyle(color: textColor(context), fontSize: 14, fontWeight: FontWeight.w700)),
              if (showLora) ...[const SizedBox(width: 6), _LoraBadge(loraOk: loraOk)],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _GearIcon(motorOn: motorOn, buzzer: buzzer, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(motorName, style: TextStyle(color: textColor(context), fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(motorOn ? 'Running' : 'Stopped',
                    style: TextStyle(color: labelColor(context), fontSize: 10)),
                ],
              )),
              _PowerButton(motorOn: motorOn, onOn: onOn, onOff: onOff, buzzer: buzzer, compact: true),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ─── Pill card (E) ──────────────────────────────────────────────────────────
class _PillCard extends StatelessWidget {
  final String label;
  final String state;
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final bool showLora;
  final bool loraOk;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _PillCard({
    required this.label, required this.state,
    required this.motorName, required this.motorOn,
    required this.buzzer, required this.showLora,
    required this.loraOk, required this.onOn,
    required this.onOff, required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1e212d).withOpacity(0.9), const Color(0xFF14161e).withOpacity(0.95)]
              : [Colors.white.withOpacity(0.95), const Color(0xFFF5F5FA).withOpacity(0.98)],
        ),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        // Mini water gauge circle
        _WaterFillCircle(state, size: 64),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: TextStyle(color: textColor(context), fontSize: 15, fontWeight: FontWeight.w700)),
              if (showLora) ...[const SizedBox(width: 6), _LoraBadge(loraOk: loraOk)],
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _GearIcon(motorOn: motorOn, buzzer: buzzer, size: 26),
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(motorName, style: TextStyle(color: textColor(context), fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(motorOn ? 'Running' : 'Stopped',
                    style: TextStyle(color: labelColor(context), fontSize: 10)),
                ],
              )),
              _RoundPowerButton(motorOn: motorOn, onOn: onOn, onOff: onOff, buzzer: buzzer),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ─── Animated gear icon ──────────────────────────────────────────────────────
class _GearIcon extends StatefulWidget {
  final bool motorOn;
  final bool buzzer;
  final double size;
  const _GearIcon({required this.motorOn, required this.buzzer, this.size = 40});

  @override
  State<_GearIcon> createState() => _GearIconState();
}

class _GearIconState extends State<_GearIcon> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _updateAnimation();
  }

  @override
  void didUpdateWidget(_GearIcon old) {
    super.didUpdateWidget(old);
    if (widget.motorOn != old.motorOn || widget.buzzer != old.buzzer) _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.motorOn) {
      _ctrl.repeat();
    } else if (widget.buzzer) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greenC = accentGreen(context);
    final bg = widget.motorOn
        ? greenC.withOpacity(0.15)
        : widget.buzzer
            ? kOrange.withOpacity(0.15)
            : cardBd(context);
    final iconColor = widget.motorOn
        ? greenC
        : widget.buzzer ? kOrange : labelColor(context);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final angle = widget.motorOn
            ? _ctrl.value * 2 * pi
            : widget.buzzer
                ? (0.5 - _ctrl.value) * 0.3
                : 0.0;
        return Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.size * 0.25),
          ),
          child: Transform.rotate(
            angle: angle,
            child: Icon(Icons.settings, color: iconColor, size: widget.size * 0.55),
          ),
        );
      },
    );
  }
}

// ─── Power ON/OFF button ─────────────────────────────────────────────────────
class _PowerButton extends StatelessWidget {
  final bool motorOn;
  final bool buzzer;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final bool compact;
  final bool expanded;
  const _PowerButton({
    required this.motorOn, required this.onOn, required this.onOff,
    this.buzzer = false, this.compact = false, this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final VoidCallback action;
    final List<Color> gradient;
    final Color fg;
    final String text;
    final IconData icon;

    if (buzzer) {
      action = onOff;
      gradient = const [Color(0xFFe65100), Color(0xFFff6d00)];
      fg = Colors.white;
      text = 'CANCEL';
      icon = Icons.cancel_outlined;
    } else if (motorOn) {
      action = onOff;
      gradient = const [Color(0xFFd32f2f), Color(0xFFff5252)];
      fg = Colors.white;
      text = 'POWER OFF';
      icon = Icons.power_settings_new;
    } else {
      action = onOn;
      if (isDark) {
        gradient = const [Color(0xFF00c853), Color(0xFF00e676)];
        fg = const Color(0xFF0a1a0a);
      } else {
        gradient = const [Color(0xFF1565c0), Color(0xFF1976D2)];
        fg = Colors.white;
      }
      text = 'POWER ON';
      icon = Icons.power_settings_new;
    }

    final double radius = compact ? 8 : 12;

    if (compact) {
      return GestureDetector(
        onTap: action,
        child: Container(
          width: 70, height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Center(
            child: Text(buzzer ? 'CANCEL' : (motorOn ? 'OFF' : 'ON'),
              style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    // Full-size button (default + expanded)
    return GestureDetector(
      onTap: action,
      child: Container(
        constraints: expanded ? null : const BoxConstraints(minWidth: 120),
        width: expanded ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 0 : 14,
          vertical: expanded ? 8 : 7,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 14),
            const SizedBox(width: 5),
            Text(text,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Round power button (Concept E pill) ─────────────────────────────────────
class _RoundPowerButton extends StatelessWidget {
  final bool motorOn;
  final bool buzzer;
  final VoidCallback onOn;
  final VoidCallback onOff;
  const _RoundPowerButton({required this.motorOn, required this.onOn, required this.onOff, this.buzzer = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> gradient;
    final Color fg;
    final IconData icon;
    final VoidCallback action;

    if (buzzer) {
      gradient = const [Color(0xFFe65100), Color(0xFFff6d00)];
      fg = Colors.white;
      icon = Icons.cancel_outlined;
      action = onOff;
    } else if (motorOn) {
      gradient = const [Color(0xFFd32f2f), Color(0xFFff5252)];
      fg = Colors.white;
      icon = Icons.power_settings_new;
      action = onOff;
    } else {
      if (isDark) {
        gradient = const [Color(0xFF00c853), Color(0xFF00e676)];
        fg = const Color(0xFF0a1a0a);
      } else {
        gradient = const [Color(0xFF1565c0), Color(0xFF1976D2)];
        fg = Colors.white;
      }
      icon = Icons.power_settings_new;
      action = onOn;
    }

    return GestureDetector(
      onTap: action,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: gradient,
          ),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: fg, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept G — Pro unified cards (each tank is one full-width card)
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptGDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptGDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      _ProTankCard(
        label: 'Overhead',
        state: s?.ohState ?? '',
        motorName: d.ohMotorName,
        motorOn: s?.ohMotor ?? false,
        buzzer: d.ohBuzzer,
        showLora: true,
        loraOk: s?.loraOk ?? true,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        context: context,
      ),
      const SizedBox(height: 14),
      _ProTankCard(
        label: 'Underground',
        state: s?.ugState ?? '',
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        showLora: false,
        loraOk: true,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        context: context,
      ),
    ]);
  }
}

// ─── Pro unified tank card ───────────────────────────────────────────────────
class _ProTankCard extends StatelessWidget {
  final String label;
  final String state;
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final bool showLora;
  final bool loraOk;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _ProTankCard({
    required this.label, required this.state,
    required this.motorName, required this.motorOn,
    required this.buzzer, required this.showLora,
    required this.loraOk, required this.onOn,
    required this.onOff, required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stateClr = _stateColor(state, context);
    final pct = _statePct(state);
    final lbl = _stateLabel(state);
    final greenC = accentGreen(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBd(context)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          // Left accent strip
          Container(
            width: 5,
            decoration: BoxDecoration(
              color: stateClr,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row: label + LoRa + state badge
                  Row(children: [
                    Icon(
                      Icons.water_drop_outlined,
                      color: stateClr,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(label,
                      style: TextStyle(
                        color: textColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (showLora) ...[
                      const SizedBox(width: 8),
                      _LoraBadge(loraOk: loraOk),
                    ],
                    const Spacer(),
                    // State badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: stateClr.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(lbl,
                        style: TextStyle(
                          color: stateClr,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 14),

                  // ── Progress bar
                  _ProLevelBar(pct: pct, color: stateClr, context: context),

                  const SizedBox(height: 6),

                  // ── Percentage text
                  Row(children: [
                    Text(
                      pct > 0 ? '${(pct * 100).toInt()}%' : '0%',
                      style: TextStyle(
                        color: stateClr,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Water Level',
                      style: TextStyle(
                        color: labelColor(context),
                        fontSize: 11,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // ── Divider
                  Container(
                    height: 1,
                    color: cardBd(context),
                  ),

                  const SizedBox(height: 12),

                  // ── Motor row
                  Row(children: [
                    _GearIcon(motorOn: motorOn, buzzer: buzzer, size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(motorName,
                            style: TextStyle(
                              color: textColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            Container(
                              width: 7, height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: motorOn ? greenC : labelColor(context),
                                boxShadow: motorOn
                                    ? [BoxShadow(color: greenC.withOpacity(0.5), blurRadius: 8)]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              motorOn ? 'Running' : 'Stopped',
                              style: TextStyle(
                                color: motorOn ? greenC : labelColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (buzzer) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.notifications_active, color: kOrange, size: 14),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    _ProToggleButton(
                      motorOn: motorOn,
                      buzzer: buzzer,
                      onOn: onOn,
                      onOff: onOff,
                      context: context,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Pro horizontal level bar with animated shimmer ──────────────────────────
class _ProLevelBar extends StatefulWidget {
  final double pct;
  final Color color;
  final BuildContext context;
  const _ProLevelBar({required this.pct, required this.color, required this.context});

  @override
  State<_ProLevelBar> createState() => _ProLevelBarState();
}

class _ProLevelBarState extends State<_ProLevelBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackColor = cardBd(widget.context);

    return SizedBox(
      height: 10,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(children: [
          // Track
          Container(
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          // Fill
          if (widget.pct > 0)
            FractionallySizedBox(
              widthFactor: widget.pct,
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (_, __) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          widget.color,
                          widget.color.withOpacity(0.7),
                          widget.color,
                        ],
                        stops: [
                          (_shimmer.value - 0.3).clamp(0.0, 1.0),
                          _shimmer.value,
                          (_shimmer.value + 0.3).clamp(0.0, 1.0),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Pro toggle button (compact outlined pill) ──────────────────────────────
class _ProToggleButton extends StatelessWidget {
  final bool motorOn;
  final bool buzzer;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _ProToggleButton({
    required this.motorOn, required this.buzzer,
    required this.onOn, required this.onOff,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final VoidCallback action;
    final Color bg;
    final Color fg;
    final String text;
    final IconData icon;

    if (buzzer) {
      action = onOff;
      bg = kOrange;
      fg = Colors.white;
      text = 'Cancel';
      icon = Icons.cancel_outlined;
    } else if (motorOn) {
      action = onOff;
      bg = isDark ? kRed : const Color(0xFFDC2626);
      fg = Colors.white;
      text = 'Stop';
      icon = Icons.stop_circle_outlined;
    } else {
      action = onOn;
      bg = isDark ? const Color(0xFF00c853) : const Color(0xFF1565c0);
      fg = Colors.white;
      text = 'Start';
      icon = Icons.play_circle_outlined;
    }

    return GestureDetector(
      onTap: action,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: bg.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 5),
          Text(text,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }
}
