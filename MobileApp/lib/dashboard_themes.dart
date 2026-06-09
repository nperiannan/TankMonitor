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
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
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
// Concept F — Hybrid: arc gauges + 2-col motor grid (DEFAULT)
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
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
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
// Eye-pleasing Material palette colors — same meaning on both themes.
const _kFullDark  = Color(0xFF66bb6a); // Green 400
const _kFullLight = Color(0xFF43a047); // Green 600
const _kHalfDark  = Color(0xFFfdd835); // Yellow 600
const _kHalfLight = Color(0xFFF9A825); // Yellow 800
const _kLowDark   = Color(0xFFffa726); // Orange 400
const _kLowLight  = Color(0xFFef6c00); // Orange 800
const _kEmptyDark = Color(0xFFef5350); // Red 400
const _kEmptyLight= Color(0xFFd32f2f); // Red 700
const _kUnknown   = Color(0xFF9e9e9e); // Grey 500

Color _stateColor(String state, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (state) {
    case 'FULL':  return isDark ? _kFullDark  : _kFullLight;
    case 'HALF':  return isDark ? _kHalfDark  : _kHalfLight;
    case 'LOW':   return isDark ? _kLowDark   : _kLowLight;
    case 'EMPTY': return isDark ? _kEmptyDark : _kEmptyLight;
    default:      return _kUnknown;
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
  return state.isNotEmpty ? 'UNKN' : 'UNKN';
}

// ─── Arc gauge circle (Concept F) ────────────────────────────────────────────
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
              Text('~${(pct * 100).toInt()}%',
                style: TextStyle(color: labelColor(context), fontSize: size * 0.10)),
              const SizedBox(height: 2),
              Text(label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.17,
                ),
              ),
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
    final r  = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const strokeW = 16.0;

    // 300° open arc (gap at bottom)
    const totalAngle = 300.0 * pi / 180; // 300 degrees
    const gapAngle   = (360.0 - 300.0) * pi / 180; // 60° gap
    const startAngle = pi / 2 + gapAngle / 2; // start just past bottom-left

    // ── Track: recessed 3D channel ──
    // Outer shadow (makes it look carved into the surface)
    canvas.drawArc(rect, startAngle, totalAngle, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round);
    // Inner shadow on track
    final trackInner = Rect.fromCircle(center: Offset(cx, cy), radius: r - 2);
    canvas.drawArc(trackInner, startAngle, totalAngle, false,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    // Track outer highlight
    final trackOuter = Rect.fromCircle(center: Offset(cx, cy), radius: r + 2);
    canvas.drawArc(trackOuter, startAngle, totalAngle, false,
      Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round);

    if (pct > 0) {
      final sweepAngle = totalAngle * pct;

      // ── Subtle outer glow ──
      canvas.drawArc(rect, startAngle, sweepAngle, false,
        Paint()
          ..color = color.withOpacity(0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      // ── Main arc — clean uniform color ──
      canvas.drawArc(rect, startAngle, sweepAngle, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round);

      // ── Highlight edge (outer) — subtle white for 3D ──
      final hlRect = Rect.fromCircle(center: Offset(cx, cy), radius: r + 3);
      canvas.drawArc(hlRect, startAngle, sweepAngle, false,
        Paint()
          ..color = Colors.white.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);

      // ── Shadow edge (inner) — very subtle ──
      final shRect = Rect.fromCircle(center: Offset(cx, cy), radius: r - 3);
      canvas.drawArc(shRect, startAngle, sweepAngle, false,
        Paint()
          ..color = Colors.black.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);

      // ── Tip dot ──
      final tipAngle = startAngle + sweepAngle;
      final tipX = cx + r * cos(tipAngle);
      final tipY = cy + r * sin(tipAngle);
      canvas.drawCircle(Offset(tipX, tipY), 6,
        Paint()..color = color);
      canvas.drawCircle(Offset(tipX, tipY), 3,
        Paint()..color = Colors.white.withOpacity(0.85));
      canvas.drawCircle(Offset(tipX, tipY), 8,
        Paint()
          ..color = color.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }

    // ── End-cap dots at track start/end ──
    final capStartX = cx + r * cos(startAngle);
    final capStartY = cy + r * sin(startAngle);
    final capEndX = cx + r * cos(startAngle + totalAngle);
    final capEndY = cy + r * sin(startAngle + totalAngle);
    final capPaint = Paint()..color = trackColor;
    canvas.drawCircle(Offset(capStartX, capStartY), strokeW / 2 - 1, capPaint);
    canvas.drawCircle(Offset(capEndX, capEndY), strokeW / 2 - 1, capPaint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.pct != pct || old.color != color;
}

// ─── AntD semi-circle gauge (Concept D) ──────────────────────────────────────
Color _antdStateColor(String state, BuildContext context) {
  return _stateColor(state, context);
}

class _SemiCircleGauge extends StatelessWidget {
  final String state;
  final double size;
  const _SemiCircleGauge(this.state, {this.size = 120});

  @override
  Widget build(BuildContext context) {
    final pctVal = _statePct(state);
    final color = _antdStateColor(state, context);
    final label = _stateLabel(state);

    return SizedBox(
      width: size,
      height: size * 0.65,
      child: CustomPaint(
        painter: _SemiCirclePainter(
          pct: pctVal,
          color: color,
          trackColor: cardBd(context),
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: Align(
          alignment: const Alignment(0, 1.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('~${(pctVal * 100).toInt()}%',
                  style: TextStyle(color: labelColor(context), fontSize: size * 0.09)),
                const SizedBox(height: 1),
                Text(label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.16,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
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
    final r  = size.width / 2 - 10;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const strokeW = 14.0;

    // 3D track — recessed channel
    canvas.drawArc(rect, pi, pi, false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round);
    // Inner shadow on track
    final innerRect = Rect.fromCircle(center: Offset(cx, cy), radius: r - 2);
    canvas.drawArc(innerRect, pi, pi, false,
      Paint()
        ..color = Colors.black.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    if (pct > 0) {
      final sweepAngle = pi * pct;

      // Subtle outer glow
      canvas.drawArc(rect, pi, sweepAngle, false,
        Paint()
          ..color = color.withOpacity(isDark ? 0.15 : 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

      // Main arc — uniform color (no dark gradient that mismatches)
      canvas.drawArc(rect, pi, sweepAngle, false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round);

      // Highlight edge (outer) — subtle white for 3D
      final highlightRect = Rect.fromCircle(center: Offset(cx, cy), radius: r + 3);
      canvas.drawArc(highlightRect, pi, sweepAngle, false,
        Paint()
          ..color = Colors.white.withOpacity(isDark ? 0.12 : 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);

      // Shadow edge (inner) — very subtle
      final shadowRect = Rect.fromCircle(center: Offset(cx, cy), radius: r - 3);
      canvas.drawArc(shadowRect, pi, sweepAngle, false,
        Paint()
          ..color = Colors.black.withOpacity(isDark ? 0.12 : 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round);

      // Tip dot
      final tipAngle = pi + sweepAngle;
      final tipX = cx + r * cos(tipAngle);
      final tipY = cy + r * sin(tipAngle);
      canvas.drawCircle(Offset(tipX, tipY), 5,
        Paint()..color = color);
      canvas.drawCircle(Offset(tipX, tipY), 2.5,
        Paint()..color = Colors.white.withOpacity(0.85));
      canvas.drawCircle(Offset(tipX, tipY), 7,
        Paint()
          ..color = color.withOpacity(0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                style: TextStyle(color: labelColor(context), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              if (showLora) _LoraBadge(loraOk: loraOk),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
    // 5-second cycle: 3s blue (0.0→0.6) then 2s grey (0.6→1.0)
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loraBlue = isDark ? const Color(0xFF448aff) : const Color(0xFF0d47a1);
    final greyColor = isDark ? const Color(0xFF78909c) : const Color(0xFF90a4ae);

    return AnimatedBuilder(
      animation: _blinkCtrl,
      builder: (_, __) {
        final Color color;
        final Color bg;
        final IconData icon;

        if (!widget.loraOk) {
          // Not OK: blink red (fade in/out over 1s cycle)
          final redPhase = (_blinkCtrl.value * 5).remainder(1.0);
          final redOpacity = (redPhase < 0.5 ? redPhase * 2 : (1.0 - redPhase) * 2).clamp(0.3, 1.0);
          color = kRed.withOpacity(redOpacity);
          bg = kRed.withOpacity(0.15 * redOpacity);
          icon = Icons.cell_tower;
        } else {
          // OK: 3s blue then 2s grey (cycle value 0→0.6 = blue, 0.6→1.0 = grey)
          final isBluePhase = _blinkCtrl.value < 0.6;
          if (isBluePhase) {
            color = loraBlue;
            bg = loraBlue.withOpacity(0.22);
          } else {
            color = greyColor;
            bg = greyColor.withOpacity(0.1);
          }
          icon = Icons.cell_tower;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(bg, Colors.white, isDark ? 0.08 : 0.3)!,
                bg,
                Color.lerp(bg, Colors.black, 0.08)!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.12), blurRadius: 6, offset: const Offset(0, 3)),
              BoxShadow(color: Colors.white.withOpacity(isDark ? 0.05 : 0.5), blurRadius: 1, offset: const Offset(0, -1)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text('LoRa', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
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

// ─── Arc gauge tank card (F) ─────────────────────────────────────────────────
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                style: TextStyle(color: labelColor(context), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              if (showLora) _LoraBadge(loraOk: loraOk),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _ArcGaugeCircle(state, size: 140),
        const SizedBox(height: 10),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenC = accentGreen(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GearIcon(motorOn: motorOn, buzzer: buzzer, size: 48),
          const SizedBox(height: 10),
          Text(motorName, style: TextStyle(color: textColor(context), fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: motorOn ? greenC : labelColor(context),
                boxShadow: motorOn ? [BoxShadow(color: greenC.withOpacity(0.6), blurRadius: 8)] : null,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              motorOn ? 'Running' : 'Stopped',
              style: TextStyle(color: labelColor(context), fontSize: 12, fontWeight: FontWeight.w500),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (!isDark) BoxShadow(
            color: Colors.white.withOpacity(0.7),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _PowerButton(motorOn: motorOn, onOn: onOn, onOff: onOff, buzzer: buzzer, expanded: true),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final greenC = accentGreen(context);
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
        final baseColor = widget.motorOn ? greenC : widget.buzzer ? kOrange : labelColor(context);
        return Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(baseColor.withOpacity(0.18), Colors.white, isDark ? 0.05 : 0.35)!,
                baseColor.withOpacity(isDark ? 0.15 : 0.12),
                Color.lerp(baseColor.withOpacity(0.12), Colors.black, 0.05)!,
              ],
            ),
            borderRadius: BorderRadius.circular(widget.size * 0.28),
            border: Border.all(
              color: baseColor.withOpacity(isDark ? 0.15 : 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(isDark ? 0.06 : 0.5),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 3,
                spreadRadius: -1,
                offset: const Offset(2, 2),
              ),
            ],
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
          vertical: expanded ? 10 : 9,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Color.lerp(gradient[0], Colors.white, 0.25)!,
              gradient[0],
              Color.lerp(gradient[1], Colors.black, 0.1)!,
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
          boxShadow: [
            BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 16),
            const SizedBox(width: 6),
            Text(text,
              style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          ],
        ),
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
