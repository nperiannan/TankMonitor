import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'tank_service.dart';
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
  // Command-feedback state machine
  final bool ugCmdSending;
  final bool ohCmdSending;
  final bool ugCmdFailed;
  final bool ohCmdFailed;
  final int  ugCd;   // buzzer countdown remaining seconds
  final int  ohCd;
  final VoidCallback? onUgClearFailed;
  final VoidCallback? onOhClearFailed;
  final bool loraOk;
  final double loraRssi;
  final double loraSNR;
  final String lastLoraReceived;

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
    this.ugCmdSending = false,
    this.ohCmdSending = false,
    this.ugCmdFailed = false,
    this.ohCmdFailed = false,
    this.ugCd = 0,
    this.ohCd = 0,
    this.onUgClearFailed,
    this.onOhClearFailed,
    this.loraOk = true,
    this.loraRssi = 0.0,
    this.loraSNR = 0.0,
    this.lastLoraReceived = '',
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
              context: context,
            )),
            const SizedBox(width: 10),
            Expanded(child: _SemiCircleTankCard(
              label: 'Overhead',
              state: s?.ohState ?? '',
              loraOk: d.loraOk,
              loraRssi: d.loraRssi,
              loraSNR: d.loraSNR,
              lastLoraReceived: d.lastLoraReceived,
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
          sending: d.ugCmdSending,
          failed: d.ugCmdFailed,
          cd: s?.ugCd ?? 0,
          onOn: d.onUgOn,
          onOff: d.onUgOff,
          onClearFailed: d.onUgClearFailed,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _GridMotorButton(
          motorOn: s?.ohMotor ?? false,
          buzzer: d.ohBuzzer,
          sending: d.ohCmdSending,
          failed: d.ohCmdFailed,
          cd: s?.ohCd ?? 0,
          onOn: d.onOhOn,
          onOff: d.onOhOff,
          onClearFailed: d.onOhClearFailed,
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
              context: context,
            )),
            const SizedBox(width: 10),
            Expanded(child: _ArcTankCard(
              label: 'Overhead',
              state: s?.ohState ?? '',
              loraOk: d.loraOk,
              loraRssi: d.loraRssi,
              loraSNR: d.loraSNR,
              lastLoraReceived: d.lastLoraReceived,
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
          sending: d.ugCmdSending,
          failed: d.ugCmdFailed,
          cd: s?.ugCd ?? 0,
          onOn: d.onUgOn,
          onOff: d.onUgOff,
          onClearFailed: d.onUgClearFailed,
          context: context,
        )),
        const SizedBox(width: 10),
        Expanded(child: _GridMotorButton(
          motorOn: s?.ohMotor ?? false,
          buzzer: d.ohBuzzer,
          sending: d.ohCmdSending,
          failed: d.ohCmdFailed,
          cd: s?.ohCd ?? 0,
          onOn: d.onOhOn,
          onOff: d.onOhOff,
          onClearFailed: d.onOhClearFailed,
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
// "Full" is green on dark, but blue on light: Green 600 washes out against the
// pale #F0F4F8 background and clashes with the blue the rest of the light theme
// already uses (gear icon, running dot, POWER ON). HALF/LOW/EMPTY keep their
// amber → orange → red ramp on both themes so "needs attention" still stands out.
const _kFullDark  = Color(0xFF66bb6a); // Green 400
const _kFullLight = Color(0xFF1976D2); // Blue 700
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
  final bool? loraOk;
  final double? loraRssi;
  final double? loraSNR;
  final String? lastLoraReceived;
  final BuildContext context;

  const _SemiCircleTankCard({
    required this.label, required this.state,
    required this.context,
    this.loraOk, this.loraRssi, this.loraSNR, this.lastLoraReceived,
  });

  bool get _isOH => loraOk != null;

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
              if (_isOH)
                _RfAntennaIcon(
                  loraOk: loraOk!, loraRssi: loraRssi ?? 0,
                  loraSNR: loraSNR ?? 0, lastLoraReceived: lastLoraReceived ?? '',
                  size: 16, context: context,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SemiCircleGauge(state),
      ]),
    );
  }
}

// ─── RF Antenna icon with tooltip ────────────────────────────────────────────
class _RfAntennaIcon extends StatelessWidget {
  final bool loraOk;
  final double loraRssi;
  final double loraSNR;
  final String lastLoraReceived;
  final double size;
  final BuildContext context;

  const _RfAntennaIcon({
    required this.loraOk, required this.loraRssi,
    required this.loraSNR, required this.lastLoraReceived,
    required this.context, this.size = 18,
  });

  String get _tooltipText {
    if (!loraOk) return 'RF: No signal';
    final rssi = loraRssi.toStringAsFixed(1);
    final snr = loraSNR.toStringAsFixed(1);
    final last = lastLoraReceived.isNotEmpty ? lastLoraReceived : '—';
    return 'RF: $rssi dBm  SNR: $snr dB\nLast: $last';
  }

  @override
  Widget build(BuildContext _) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = loraOk
        ? (isDark ? const Color(0xFF66bb6a) : const Color(0xFF43a047))
        : kRed;
    return GestureDetector(
      onTap: () {
        // RF data is otherwise event/keep-alive driven — request a fresh
        // snapshot on tap instead of showing a potentially stale reading.
        context.read<TankService>().syncNow();
        _showRfModal(context, isDark);
      },
      child: Icon(Icons.cell_tower, color: color, size: size),
    );
  }

  void _showRfModal(BuildContext ctx, bool isDark) {
    final rssi = loraRssi.toStringAsFixed(1);
    final snr = loraSNR.toStringAsFixed(1);
    final last = lastLoraReceived.isNotEmpty ? lastLoraReceived : '—';

    // Signal quality label
    final String quality;
    final Color qualityClr;
    if (!loraOk) {
      quality = 'No Signal';
      qualityClr = kRed;
    } else if (loraRssi > -80) {
      quality = 'Excellent';
      qualityClr = isDark ? const Color(0xFF66bb6a) : const Color(0xFF43a047);
    } else if (loraRssi > -100) {
      quality = 'Good';
      qualityClr = isDark ? const Color(0xFFfdd835) : const Color(0xFFF9A825);
    } else if (loraRssi > -115) {
      quality = 'Weak';
      qualityClr = isDark ? const Color(0xFFffa726) : const Color(0xFFef6c00);
    } else {
      quality = 'Very Weak';
      qualityClr = kRed;
    }

    showDialog(
      context: ctx,
      builder: (c) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1e1e1e) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(children: [
                Icon(Icons.cell_tower, color: qualityClr, size: 24),
                const SizedBox(width: 10),
                Text('RF Signal Status',
                  style: TextStyle(
                    color: textColor(ctx),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(c).pop(),
                  child: Icon(Icons.close, color: labelColor(ctx), size: 20),
                ),
              ]),
              const SizedBox(height: 16),
              // Signal quality badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: qualityClr.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(quality,
                    style: TextStyle(
                      color: qualityClr,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    )),
                ),
              ),
              const SizedBox(height: 16),
              // Detail rows
              _rfRow(ctx, 'RSSI', '$rssi dBm', isDark),
              const SizedBox(height: 8),
              _rfRow(ctx, 'SNR', '$snr dB', isDark),
              const SizedBox(height: 8),
              _rfRow(ctx, 'Last Received', last, isDark),
              const SizedBox(height: 8),
              _rfRow(ctx, 'Link', loraOk ? 'Connected' : 'Lost', isDark,
                  valueColor: loraOk ? qualityClr : kRed),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _rfRow(BuildContext ctx, String label, String value, bool isDark,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
            style: TextStyle(color: labelColor(ctx), fontSize: 12, fontWeight: FontWeight.w500)),
          Text(value,
            style: TextStyle(
              color: valueColor ?? textColor(ctx),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
        ],
      ),
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
  final bool? loraOk;
  final double? loraRssi;
  final double? loraSNR;
  final String? lastLoraReceived;
  final BuildContext context;

  const _ArcTankCard({
    required this.label, required this.state,
    required this.context,
    this.loraOk, this.loraRssi, this.loraSNR, this.lastLoraReceived,
  });

  bool get _isOH => loraOk != null;

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
              if (_isOH)
                _RfAntennaIcon(
                  loraOk: loraOk!, loraRssi: loraRssi ?? 0,
                  loraSNR: loraSNR ?? 0, lastLoraReceived: lastLoraReceived ?? '',
                  size: 16, context: context,
                ),
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
  final bool sending;
  final bool failed;
  final int cd;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final VoidCallback? onClearFailed;
  final BuildContext context;

  const _GridMotorButton({
    required this.motorOn, required this.onOn,
    required this.onOff, required this.context,
    this.buzzer = false,
    this.sending = false,
    this.failed = false,
    this.cd = 0,
    this.onClearFailed,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Failed-delivery banner (auto-clears after 10s; tap X to dismiss).
          if (failed && !sending) ...[
            _NotDeliveredBanner(onDismiss: onClearFailed),
            const SizedBox(height: 10),
          ],
          _PowerButton(
            motorOn: motorOn, onOn: onOn, onOff: onOff,
            buzzer: buzzer, sending: sending, cd: cd, expanded: true,
          ),
          // Shrinking countdown bar while the buzzer is sounding.
          if (buzzer && !sending) ...[
            const SizedBox(height: 10),
            _CountdownBar(seconds: cd, color: kOrange),
          ],
        ],
      ),
    );
  }
}

// ─── "Not delivered" banner ──────────────────────────────────────────────────
class _NotDeliveredBanner extends StatelessWidget {
  final VoidCallback? onDismiss;
  const _NotDeliveredBanner({this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final red = accentRed(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: red.withOpacity(0.12),
        border: Border.all(color: red.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: red, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Not delivered — no ack from controller',
            style: TextStyle(color: red, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.2),
          ),
        ),
        if (onDismiss != null)
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: red.withOpacity(0.8), size: 14),
          ),
      ]),
    );
  }
}

// ─── Shrinking buzzer countdown bar ──────────────────────────────────────────
class _CountdownBar extends StatefulWidget {
  final int seconds;   // remaining seconds reported by the controller
  final Color color;
  const _CountdownBar({required this.seconds, required this.color});

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar> {
  double _total = 1;
  double _remaining = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _sync();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => _remaining = (_remaining - 0.1).clamp(0.0, _total));
    });
  }

  @override
  void didUpdateWidget(_CountdownBar old) {
    super.didUpdateWidget(old);
    if (widget.seconds != old.seconds) _sync();
  }

  // Resync to the controller's authoritative remaining value; remember the
  // largest value seen as the bar's full scale.
  void _sync() {
    final s = widget.seconds.toDouble();
    if (s > _total) _total = s;
    if (_total <= 0) _total = 1;
    setState(() => _remaining = s);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frac = (_remaining / _total).clamp(0.0, 1.0);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            backgroundColor: widget.color.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(widget.color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Starting in ${_remaining.ceil()}s…',
          style: TextStyle(color: widget.color, fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ─── Press-down scale wrapper (tactile button feel) ──────────────────────────
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          child: widget.child,
        ),
      ),
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
  final bool sending;
  final int cd;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final bool compact;
  final bool expanded;
  const _PowerButton({
    required this.motorOn, required this.onOn, required this.onOff,
    this.buzzer = false, this.sending = false, this.cd = 0,
    this.compact = false, this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final VoidCallback? action;
    final List<Color> gradient;
    final Color fg;
    final String text;
    final IconData icon;

    if (sending) {
      // Waiting for the controller to acknowledge — button is disabled.
      action = null;
      gradient = isDark
          ? const [Color(0xFF37474F), Color(0xFF455A64)]
          : const [Color(0xFF78909C), Color(0xFF90A4AE)];
      fg = Colors.white;
      text = 'Sending…';
      icon = Icons.sync;
    } else if (buzzer) {
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
      return _PressableScale(
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
            child: sending
                ? SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
                  )
                : Text(buzzer ? 'CANCEL' : (motorOn ? 'OFF' : 'ON'),
                    style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    // Full-size button (default + expanded)
    return _PressableScale(
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
            if (sending)
              SizedBox(
                width: 15, height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
              )
            else
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
        sending: d.ohCmdSending,
        failed: d.ohCmdFailed,
        cd: s?.ohCd ?? 0,
        loraOk: d.loraOk,
        loraRssi: d.loraRssi,
        loraSNR: d.loraSNR,
        lastLoraReceived: d.lastLoraReceived,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        onClearFailed: d.onOhClearFailed,
        context: context,
      ),
      const SizedBox(height: 14),
      _ProTankCard(
        label: 'Underground',
        state: s?.ugState ?? '',
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        sending: d.ugCmdSending,
        failed: d.ugCmdFailed,
        cd: s?.ugCd ?? 0,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        onClearFailed: d.onUgClearFailed,
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
  final bool sending;
  final bool failed;
  final int cd;
  final bool? loraOk;
  final double? loraRssi;
  final double? loraSNR;
  final String? lastLoraReceived;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final VoidCallback? onClearFailed;
  final BuildContext context;

  const _ProTankCard({
    required this.label, required this.state,
    required this.motorName, required this.motorOn,
    required this.buzzer, required this.onOn,
    required this.onOff, required this.context,
    this.sending = false, this.failed = false, this.cd = 0,
    this.onClearFailed,
    this.loraOk, this.loraRssi, this.loraSNR, this.lastLoraReceived,
  });

  bool get _isOH => loraOk != null;

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
                  // ── Header row: label + RF icon + state badge
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
                    if (_isOH) ...[
                      const SizedBox(width: 6),
                      _RfAntennaIcon(
                        loraOk: loraOk!, loraRssi: loraRssi ?? 0,
                        loraSNR: loraSNR ?? 0, lastLoraReceived: lastLoraReceived ?? '',
                        size: 16, context: context,
                      ),
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
                              sending ? 'Sending…' : (motorOn ? 'Running' : 'Stopped'),
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
                      sending: sending,
                      onOn: onOn,
                      onOff: onOff,
                      context: context,
                    ),
                  ]),
                  // Shrinking countdown bar while the buzzer is sounding.
                  if (buzzer && !sending) ...[
                    const SizedBox(height: 10),
                    _CountdownBar(seconds: cd, color: kOrange),
                  ],
                  // Failed-delivery banner (auto-clears after 10s).
                  if (failed && !sending) ...[
                    const SizedBox(height: 10),
                    _NotDeliveredBanner(onDismiss: onClearFailed),
                  ],
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
  final bool sending;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final BuildContext context;

  const _ProToggleButton({
    required this.motorOn, required this.buzzer,
    required this.onOn, required this.onOff,
    required this.context,
    this.sending = false,
  });

  @override
  Widget build(BuildContext _) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final VoidCallback? action;
    final Color bg;
    final Color fg;
    final String text;
    final IconData icon;

    if (sending) {
      action = null;
      bg = isDark ? const Color(0xFF455A64) : const Color(0xFF90A4AE);
      fg = Colors.white;
      text = 'Sending…';
      icon = Icons.sync;
    } else if (buzzer) {
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

    return _PressableScale(
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
          if (sending)
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
            )
          else
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

// ═══════════════════════════════════════════════════════════════════════════════
// Concept Flow — vertical schematic of the real plumbing
//   House ← Overhead ← [OH motor] ← Underground ← [UG motor] ← Borewell
// The layout itself explains the system, so "which way is water moving" is
// answerable at a glance instead of having to map two abstract cards onto the
// physical tanks.
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptFlowDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptFlowDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(children: [
      if (s?.txLost == true) ...[
        _LostBanner(lastKnown: s?.ohLastKnown ?? '', context: context),
        const SizedBox(height: 10),
      ],
      Container(
        padding: const EdgeInsets.all(14),
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
          Row(children: [
            Text('WATER SYSTEM',
              style: TextStyle(color: labelColor(context), fontSize: 10,
                  letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            const Spacer(),
            _RfAntennaIcon(
              loraOk: d.loraOk, loraRssi: d.loraRssi,
              loraSNR: d.loraSNR, lastLoraReceived: d.lastLoraReceived,
              size: 16, context: context,
            ),
          ]),
          const SizedBox(height: 12),
          // ── House ← Overhead tank ─────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _FlowEndpoint(icon: Icons.shower, label: 'House', context: context),
            const SizedBox(width: 10),
            Expanded(child: _FlowTank(
              label: 'Overhead',
              state: s?.ohState ?? '',
              height: 62,
              context: context,
            )),
          ]),
          _FlowPump(
            name: d.ohMotorName,
            motorOn: s?.ohMotor ?? false,
            buzzer: d.ohBuzzer,
            sending: d.ohCmdSending,
            failed: d.ohCmdFailed,
            cd: s?.ohCd ?? 0,
            onOn: d.onOhOn,
            onOff: d.onOhOff,
            onClearFailed: d.onOhClearFailed,
            context: context,
          ),
          // ── Underground tank ──────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const SizedBox(width: 44),
            Expanded(child: _FlowTank(
              label: 'Underground',
              state: s?.ugState ?? '',
              height: 50,
              context: context,
            )),
          ]),
          _FlowPump(
            name: d.ugMotorName,
            motorOn: s?.ugMotor ?? false,
            buzzer: d.ugBuzzer,
            sending: d.ugCmdSending,
            failed: d.ugCmdFailed,
            cd: s?.ugCd ?? 0,
            onOn: d.onUgOn,
            onOff: d.onUgOff,
            onClearFailed: d.onUgClearFailed,
            context: context,
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.water_drop_outlined, size: 13, color: labelColor(context)),
            const SizedBox(width: 5),
            Text('Borewell source',
              style: TextStyle(color: labelColor(context), fontSize: 11)),
          ]),
        ]),
      ),
    ]);
  }
}

// ─── Flow: fixed endpoint marker (house / source) ────────────────────────────
class _FlowEndpoint extends StatelessWidget {
  final IconData icon;
  final String label;
  final BuildContext context;
  const _FlowEndpoint({required this.icon, required this.label, required this.context});

  @override
  Widget build(BuildContext _) => SizedBox(
    width: 44,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 17, color: labelColor(context)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: labelColor(context), fontSize: 9.5)),
    ]),
  );
}

// ─── Flow: horizontal tank with a bottom-up fill ─────────────────────────────
class _FlowTank extends StatelessWidget {
  final String label;
  final String state;
  final double height;
  final BuildContext context;
  const _FlowTank({
    required this.label, required this.state,
    required this.height, required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final color = _stateColor(state, context);
    final pct   = _statePct(state);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(label.toUpperCase(),
          style: TextStyle(color: labelColor(context), fontSize: 9.5,
              letterSpacing: 0.8, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(_stateLabel(state),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: subtleBg(context),
            border: Border.all(color: cardBd(context)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Stack(children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: pct == 0 ? 0.0001 : pct,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [color.withOpacity(0.85), color.withOpacity(0.5)],
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Text('~${(pct * 100).toInt()}%',
                style: TextStyle(
                  color: textColor(context),
                  fontSize: height > 55 ? 16 : 14,
                  fontWeight: FontWeight.w800,
                )),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ─── Flow: inline pump row sitting between two tanks ─────────────────────────
class _FlowPump extends StatelessWidget {
  final String name;
  final bool motorOn;
  final bool buzzer;
  final bool sending;
  final bool failed;
  final int cd;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final VoidCallback? onClearFailed;
  final BuildContext context;

  const _FlowPump({
    required this.name, required this.motorOn, required this.buzzer,
    required this.sending, required this.failed, required this.cd,
    required this.onOn, required this.onOff, required this.context,
    this.onClearFailed,
  });

  @override
  Widget build(BuildContext _) {
    final green  = accentGreen(context);
    final active = motorOn || buzzer;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: active ? green.withOpacity(0.07) : subtleBg(context),
          border: Border.all(color: active ? green : cardBd(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          if (failed && !sending) ...[
            _NotDeliveredBanner(onDismiss: onClearFailed),
            const SizedBox(height: 8),
          ],
          Row(children: [
            _GearIcon(motorOn: motorOn, buzzer: buzzer, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor(context), fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Row(children: [
                    if (motorOn) ...[
                      Icon(Icons.arrow_upward, size: 11, color: green),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      motorOn ? 'Pumping up' : (buzzer ? 'Starting…' : 'Idle'),
                      style: TextStyle(
                        color: active ? green : labelColor(context),
                        fontSize: 10.5,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PowerButton(
              motorOn: motorOn, onOn: onOn, onOff: onOff,
              buzzer: buzzer, sending: sending, cd: cd, compact: true,
            ),
          ]),
          if (buzzer && !sending) ...[
            const SizedBox(height: 9),
            _CountdownBar(seconds: cd, color: kOrange),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept Clean — one calm card per tank+motor pair, large typography and a
// coloured accent rail instead of coloured borders everywhere.
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptCleanDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptCleanDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      if (s?.txLost == true) ...[
        _LostBanner(lastKnown: s?.ohLastKnown ?? '', context: context),
        const SizedBox(height: 12),
      ],
      _CleanUnitCard(
        label: 'Overhead',
        state: s?.ohState ?? '',
        motorName: d.ohMotorName,
        motorOn: s?.ohMotor ?? false,
        buzzer: d.ohBuzzer,
        sending: d.ohCmdSending,
        failed: d.ohCmdFailed,
        cd: s?.ohCd ?? 0,
        loraOk: d.loraOk,
        loraRssi: d.loraRssi,
        loraSNR: d.loraSNR,
        lastLoraReceived: d.lastLoraReceived,
        onOn: d.onOhOn,
        onOff: d.onOhOff,
        onClearFailed: d.onOhClearFailed,
        context: context,
      ),
      const SizedBox(height: 12),
      _CleanUnitCard(
        label: 'Underground',
        state: s?.ugState ?? '',
        motorName: d.ugMotorName,
        motorOn: s?.ugMotor ?? false,
        buzzer: d.ugBuzzer,
        sending: d.ugCmdSending,
        failed: d.ugCmdFailed,
        cd: s?.ugCd ?? 0,
        onOn: d.onUgOn,
        onOff: d.onUgOff,
        onClearFailed: d.onUgClearFailed,
        context: context,
      ),
    ]);
  }
}

class _CleanUnitCard extends StatelessWidget {
  final String label;
  final String state;
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final bool sending;
  final bool failed;
  final int cd;
  final bool? loraOk;
  final double? loraRssi;
  final double? loraSNR;
  final String? lastLoraReceived;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final VoidCallback? onClearFailed;
  final BuildContext context;

  const _CleanUnitCard({
    required this.label, required this.state, required this.motorName,
    required this.motorOn, required this.buzzer, required this.sending,
    required this.failed, required this.cd,
    required this.onOn, required this.onOff, required this.context,
    this.loraOk, this.loraRssi, this.loraSNR, this.lastLoraReceived,
    this.onClearFailed,
  });

  bool get _isOH => loraOk != null;

  @override
  Widget build(BuildContext _) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = _stateColor(state, context);
    final pct    = _statePct(state);
    final green  = accentGreen(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg(context),
        border: Border.all(color: cardBd(context)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 4, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${label.toUpperCase()} TANK',
                          style: TextStyle(color: labelColor(context), fontSize: 9.5,
                              letterSpacing: 1, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(_stateLabel(state),
                          style: TextStyle(color: textColor(context), fontSize: 26,
                              fontWeight: FontWeight.w800, height: 1.15)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (_isOH)
                        _RfAntennaIcon(
                          loraOk: loraOk!, loraRssi: loraRssi ?? 0,
                          loraSNR: loraSNR ?? 0, lastLoraReceived: lastLoraReceived ?? '',
                          size: 15, context: context,
                        ),
                      if (_isOH) const SizedBox(height: 4),
                      Text('~${(pct * 100).toInt()}%',
                        style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('level',
                        style: TextStyle(color: labelColor(context), fontSize: 9.5)),
                    ]),
                  ]),
                  const SizedBox(height: 11),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: subtleBg(context),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Divider(height: 1, color: cardBd(context)),
                  const SizedBox(height: 10),
                  if (failed && !sending) ...[
                    _NotDeliveredBanner(onDismiss: onClearFailed),
                    const SizedBox(height: 9),
                  ],
                  Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: motorOn ? green : labelColor(context),
                        boxShadow: motorOn
                            ? [BoxShadow(color: green.withOpacity(0.6), blurRadius: 8)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(motorName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor(context), fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      motorOn ? 'Running' : (buzzer ? 'Starting…' : 'Idle'),
                      style: TextStyle(
                        color: (motorOn || buzzer) ? green : labelColor(context),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PowerButton(
                      motorOn: motorOn, onOn: onOn, onOff: onOff,
                      buzzer: buzzer, sending: sending, cd: cd, compact: true,
                    ),
                  ]),
                  if (buzzer && !sending) ...[
                    const SizedBox(height: 10),
                    _CountdownBar(seconds: cd, color: kOrange),
                  ],
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept Console — dense, information-first: segmented level meters and both
// motors visible without scrolling.
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptConsoleDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptConsoleDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final green  = accentGreen(context);

    return Column(children: [
      if (s?.txLost == true) ...[
        _LostBanner(lastKnown: s?.ohLastKnown ?? '', context: context),
        const SizedBox(height: 8),
      ],
      // ── Status strip ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg(context),
          border: Border.all(color: cardBd(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: d.connected ? green : accentRed(context),
              ),
            ),
            const SizedBox(width: 6),
            Text(d.connected ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: d.connected ? green : accentRed(context),
                fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          ]),
          Row(children: [
            _RfAntennaIcon(
              loraOk: d.loraOk, loraRssi: d.loraRssi,
              loraSNR: d.loraSNR, lastLoraReceived: d.lastLoraReceived,
              size: 14, context: context,
            ),
            const SizedBox(width: 5),
            Text('${d.loraRssi.toStringAsFixed(0)} dBm',
              style: TextStyle(color: labelColor(context), fontSize: 10)),
          ]),
          if (s?.time != null && s!.time.isNotEmpty)
            Text(s.time, style: TextStyle(color: labelColor(context), fontSize: 10)),
        ]),
      ),
      const SizedBox(height: 8),
      // ── Two dense unit rows in one card ───────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cardBg(context),
          border: Border.all(color: cardBd(context)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black38 : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          _ConsoleRow(
            code: 'OH',
            label: 'Overhead',
            state: s?.ohState ?? '',
            motorName: d.ohMotorName,
            motorOn: s?.ohMotor ?? false,
            buzzer: d.ohBuzzer,
            sending: d.ohCmdSending,
            failed: d.ohCmdFailed,
            cd: s?.ohCd ?? 0,
            onOn: d.onOhOn,
            onOff: d.onOhOff,
            onClearFailed: d.onOhClearFailed,
            context: context,
          ),
          Divider(height: 1, color: cardBd(context)),
          _ConsoleRow(
            code: 'UG',
            label: 'Underground',
            state: s?.ugState ?? '',
            motorName: d.ugMotorName,
            motorOn: s?.ugMotor ?? false,
            buzzer: d.ugBuzzer,
            sending: d.ugCmdSending,
            failed: d.ugCmdFailed,
            cd: s?.ugCd ?? 0,
            onOn: d.onUgOn,
            onOff: d.onUgOff,
            onClearFailed: d.onUgClearFailed,
            context: context,
          ),
        ]),
      ),
    ]);
  }
}

class _ConsoleRow extends StatelessWidget {
  final String code;
  final String label;
  final String state;
  final String motorName;
  final bool motorOn;
  final bool buzzer;
  final bool sending;
  final bool failed;
  final int cd;
  final VoidCallback onOn;
  final VoidCallback onOff;
  final VoidCallback? onClearFailed;
  final BuildContext context;

  const _ConsoleRow({
    required this.code, required this.label, required this.state,
    required this.motorName, required this.motorOn, required this.buzzer,
    required this.sending, required this.failed, required this.cd,
    required this.onOn, required this.onOff, required this.context,
    this.onClearFailed,
  });

  @override
  Widget build(BuildContext _) {
    final color = _stateColor(state, context);
    final pct   = _statePct(state);
    final green = accentGreen(context);
    // 10-segment meter: filled segments represent the tank level bucket.
    final filled = (pct * 10).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(children: [
        Row(children: [
          Text(code,
            style: TextStyle(color: textColor(context), fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(width: 6),
          Text(label,
            style: TextStyle(color: labelColor(context), fontSize: 10.5)),
          const Spacer(),
          Text('~${(pct * 100).toInt()}%',
            style: TextStyle(color: labelColor(context), fontSize: 10.5)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(_stateLabel(state),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 7),
        Row(children: List.generate(10, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == 9 ? 0 : 3),
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: i < filled ? color : subtleBg(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ))),
        const SizedBox(height: 9),
        if (failed && !sending) ...[
          _NotDeliveredBanner(onDismiss: onClearFailed),
          const SizedBox(height: 8),
        ],
        Row(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: motorOn ? green : labelColor(context),
              boxShadow: motorOn
                  ? [BoxShadow(color: green.withOpacity(0.6), blurRadius: 7)]
                  : null,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(motorName,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor(context), fontSize: 11.5)),
          ),
          const SizedBox(width: 6),
          Text(
            motorOn ? 'Running' : (buzzer ? 'Starting…' : 'Idle'),
            style: TextStyle(
              color: (motorOn || buzzer) ? green : labelColor(context),
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 10),
          _PowerButton(
            motorOn: motorOn, onOn: onOn, onOff: onOff,
            buzzer: buzzer, sending: sending, cd: cd, compact: true,
          ),
        ]),
        if (buzzer && !sending) ...[
          const SizedBox(height: 9),
          _CountdownBar(seconds: cd, color: kOrange),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Concept Glance — one look, one decision
//   The overhead tank is the hero (it is the only tank you draw water from),
//   the app says in plain words what that means, and there is exactly ONE big
//   button that does the right thing right now. The underground tank drops to a
//   single supporting row, because it only matters as "can I refill?".
// ═══════════════════════════════════════════════════════════════════════════════
class ConceptGlanceDashboard extends StatelessWidget {
  final DashboardData d;
  const ConceptGlanceDashboard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final s = d.status;
    return Column(children: [
      if (s?.txLost == true) ...[
        _LostBanner(lastKnown: s?.ohLastKnown ?? '', context: context),
        const SizedBox(height: 10),
      ],
      _GlanceHero(d: d),
      const SizedBox(height: 10),
      _GlanceSourceCard(d: d),
    ]);
  }
}

// ─── Glance: hero card for the overhead tank + the single action ────────────
class _GlanceHero extends StatelessWidget {
  final DashboardData d;
  const _GlanceHero({required this.d});

  @override
  Widget build(BuildContext context) {
    final s       = d.status;
    final ohState = s?.ohState ?? '';
    final ugState = s?.ugState ?? '';
    final ohOn    = s?.ohMotor ?? false;
    final ugOn    = s?.ugMotor ?? false;
    final txLost  = s?.txLost ?? false;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // ── Headline ────────────────────────────────────────────────────────────
    final String headline;
    final Color  headlineClr;
    final String subline;
    if (ohOn) {
      headline    = 'FILLING';
      headlineClr = accentBlue(context);
      subline     = '${d.ohMotorName.toUpperCase()} IS RUNNING';
    } else {
      headline    = _stateLabel(ohState);
      headlineClr = _stateColor(ohState, context);
      subline     = switch (ohState) {
        'FULL'  => 'OVERHEAD TANK IS FULL',
        'HALF'  => 'ABOUT HALF FULL',
        'LOW'   => 'RUNNING LOW',
        'EMPTY' => 'OVERHEAD TANK IS EMPTY',
        _       => 'WAITING FOR A READING',
      };
    }

    // ── Plain-English advice ────────────────────────────────────────────────
    final String adviceMain;
    final String adviceDim;
    if (txLost) {
      adviceMain = 'No signal from the transmitter.';
      adviceDim  = 'Showing the last level it reported.';
    } else if (ohOn) {
      adviceMain = 'Filling from the underground tank.';
      adviceDim  = 'You can stop it any time.';
    } else if (ugOn) {
      adviceMain = 'Borewell is filling the underground tank.';
      adviceDim  = 'Refill the overhead tank once it has water.';
    } else if (ohState == 'FULL') {
      adviceMain = 'Plenty of water upstairs.';
      adviceDim  = 'Nothing needs your attention.';
    } else if (ohState.isEmpty || ohState == 'UNKNOWN') {
      adviceMain = 'No level reading yet.';
      adviceDim  = 'Waiting for the transmitter to report.';
    } else if (ugState == 'EMPTY') {
      adviceMain = 'Overhead is ${ohState == 'EMPTY' ? 'empty' : 'running low'} '
                   'and underground is empty.';
      adviceDim  = 'Run the borewell first, then refill overhead.';
    } else {
      adviceMain = 'Overhead tank is ${ohState == 'EMPTY' ? 'empty' : 'running low'}.';
      adviceDim  = 'Underground has water — safe to refill now.';
    }

    // ── The single contextual action ────────────────────────────────────────
    final _GlanceAction act = _resolveAction(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // header
        SizedBox(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('OVERHEAD TANK',
                style: TextStyle(
                  color: labelColor(context), fontSize: 10,
                  letterSpacing: 1.3, fontWeight: FontWeight.w800)),
              _RfAntennaIcon(
                loraOk: d.loraOk, loraRssi: d.loraRssi,
                loraSNR: d.loraSNR, lastLoraReceived: d.lastLoraReceived,
                size: 16, context: context,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // tank + headline
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          _GlanceTank(state: ohState, context: context),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(headline,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: headlineClr, fontSize: 30,
                  fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -0.6)),
              const SizedBox(height: 6),
              Text(subline,
                style: TextStyle(
                  color: labelColor(context), fontSize: 10.5,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 11),
              Text(adviceMain,
                style: TextStyle(
                  color: textColor(context), fontSize: 13, height: 1.35)),
              Text(adviceDim,
                style: TextStyle(
                  color: labelColor(context), fontSize: 13, height: 1.35)),
            ]),
          ),
        ]),
        // failed-delivery notice for whichever motor the action targets
        if (act.failed && !act.sending) ...[
          const SizedBox(height: 12),
          _NotDeliveredBanner(onDismiss: act.onClearFailed),
        ],
        const SizedBox(height: 13),
        _GlanceCta(action: act),
        if (act.sub.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(act.sub,
            textAlign: TextAlign.center,
            style: TextStyle(color: labelColor(context), fontSize: 10.5)),
        ],
        if (act.cd > 0) ...[
          const SizedBox(height: 10),
          _CountdownBar(seconds: act.cd, color: kOrange),
        ],
      ]),
    );
  }

  /// Works out the one thing the user most likely wants to do right now.
  _GlanceAction _resolveAction(BuildContext context) {
    final s       = d.status;
    final ohState = s?.ohState ?? '';
    final ugState = s?.ugState ?? '';
    final ohOn    = s?.ohMotor ?? false;
    final ugOn    = s?.ugMotor ?? false;
    final oh      = d.ohMotorName.toUpperCase();
    final ug      = d.ugMotorName.toUpperCase();

    if (d.ohCmdSending || d.ugCmdSending) {
      return const _GlanceAction(
        kind: _CtaKind.sending, label: 'Sending…', icon: Icons.sync, sending: true);
    }
    if (d.ohBuzzer) {
      return _GlanceAction(
        kind: _CtaKind.cancel, label: 'CANCEL $oh', icon: Icons.cancel_outlined,
        onTap: d.onOhOff, cd: s?.ohCd ?? 0,
        sub: 'the buzzer is warning before the pump starts');
    }
    if (d.ugBuzzer) {
      return _GlanceAction(
        kind: _CtaKind.cancel, label: 'CANCEL $ug', icon: Icons.cancel_outlined,
        onTap: d.onUgOff, cd: s?.ugCd ?? 0,
        sub: 'the buzzer is warning before the pump starts');
    }
    if (ohOn) {
      return _GlanceAction(
        kind: _CtaKind.stop, label: 'STOP $oh', icon: Icons.power_settings_new,
        onTap: d.onOhOff, failed: d.ohCmdFailed, onClearFailed: d.onOhClearFailed);
    }
    if (ugOn) {
      return _GlanceAction(
        kind: _CtaKind.stop, label: 'STOP $ug', icon: Icons.power_settings_new,
        onTap: d.onUgOff, failed: d.ugCmdFailed, onClearFailed: d.onUgClearFailed,
        sub: 'the underground tank is filling');
    }
    if (ohState == 'FULL') {
      return _GlanceAction(
        kind: _CtaKind.calm, label: 'ALL GOOD', icon: Icons.check_rounded,
        onLongPress: d.onOhOn, failed: d.ohCmdFailed, onClearFailed: d.onOhClearFailed,
        sub: 'press and hold to run the ${d.ohMotorName} anyway');
    }
    if (ugState == 'EMPTY') {
      return _GlanceAction(
        kind: _CtaKind.go, label: 'START $ug', icon: Icons.play_arrow_rounded,
        onTap: d.onUgOn, failed: d.ugCmdFailed, onClearFailed: d.onUgClearFailed,
        sub: 'fills the underground tank first');
    }
    return _GlanceAction(
      kind: _CtaKind.go, label: 'START $oh', icon: Icons.play_arrow_rounded,
      onTap: d.onOhOn, failed: d.ohCmdFailed, onClearFailed: d.onOhClearFailed,
      sub: 'fills the overhead tank from underground');
  }
}

enum _CtaKind { go, stop, cancel, sending, calm }

/// Everything the hero button needs to render and behave.
class _GlanceAction {
  final _CtaKind kind;
  final String label;
  final IconData icon;
  final String sub;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool sending;
  final bool failed;
  final VoidCallback? onClearFailed;
  final int cd;

  const _GlanceAction({
    required this.kind, required this.label, required this.icon,
    this.sub = '', this.onTap, this.onLongPress,
    this.sending = false, this.failed = false, this.onClearFailed, this.cd = 0,
  });
}

// ─── Glance: the one big button ─────────────────────────────────────────────
class _GlanceCta extends StatelessWidget {
  final _GlanceAction action;
  const _GlanceCta({required this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // "Calm" is an outlined button — nothing to do, so nothing shouts.
    // Tapping deliberately does nothing; a long press starts the pump anyway.
    if (action.kind == _CtaKind.calm) {
      final clr = accentGreen(context); // green on dark, blue on light
      return GestureDetector(
        onLongPress: action.onLongPress,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: clr.withOpacity(isDark ? 0.14 : 0.12),
            border: Border.all(color: clr.withOpacity(isDark ? 0.35 : 0.40)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _label(clr),
        ),
      );
    }

    final Color base = switch (action.kind) {
      _CtaKind.stop    => accentRed(context),
      _CtaKind.cancel  => accentOrange(context),
      _CtaKind.sending => isDark ? const Color(0xFF455A64) : const Color(0xFF78909C),
      _             => accentBlue(context),
    };

    return _PressableScale(
      onTap: action.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Color.lerp(base, Colors.white, 0.14)!,
              base,
              Color.lerp(base, Colors.black, 0.10)!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
          boxShadow: [
            BoxShadow(color: base.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: _label(Colors.white),
      ),
    );
  }

  Widget _label(Color fg) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (action.sending)
        SizedBox(
          width: 15, height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(fg)),
        )
      else
        Icon(action.icon, color: fg, size: 18),
      const SizedBox(width: 8),
      Flexible(
        child: Text(action.label,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: fg, fontSize: 14,
            fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      ),
    ],
  );
}

// ─── Glance: physical-looking overhead tank ─────────────────────────────────
class _GlanceTank extends StatelessWidget {
  final String state;
  final BuildContext context;
  const _GlanceTank({required this.state, required this.context});

  @override
  Widget build(BuildContext _) {
    final pct   = _statePct(state);
    final color = _stateColor(state, context);
    final line  = labelColor(context).withOpacity(0.35);

    return Container(
      width: 82, height: 132,
      decoration: BoxDecoration(
        color: subtleBg(context),
        border: Border.all(color: cardBd(context), width: 2),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(10), bottom: Radius.circular(14)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8), bottom: Radius.circular(12)),
        child: Stack(children: [
          // quarter markings
          Positioned.fill(
            child: Column(children: [
              for (int i = 0; i < 3; i++) ...[
                const Spacer(),
                Container(height: 1, color: line),
              ],
              const Spacer(),
            ]),
          ),
          // water
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: pct == 0 ? 0.0001 : pct,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [color.withOpacity(0.78), color],
                  ),
                ),
              ),
            ),
          ),
          // level %
          Center(
            child: Text('${(pct * 100).round()}%',
              style: TextStyle(
                color: pct >= 0.5 ? Colors.white : textColor(context),
                fontSize: 18, fontWeight: FontWeight.w900,
                shadows: pct >= 0.5
                    ? const [Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1))]
                    : null,
              )),
          ),
        ]),
      ),
    );
  }
}

// ─── Glance: the underground tank, demoted to one supporting row ────────────
class _GlanceSourceCard extends StatelessWidget {
  final DashboardData d;
  const _GlanceSourceCard({required this.d});

  @override
  Widget build(BuildContext context) {
    final s      = d.status;
    final state  = s?.ugState ?? '';
    final motorOn = s?.ugMotor ?? false;
    final cd     = s?.ugCd ?? 0;
    final pct    = _statePct(state);
    final color  = _stateColor(state, context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String sub = motorOn
        ? '${d.ugMotorName} running'
        : d.ugBuzzer ? '${d.ugMotorName} starting…' : '${d.ugMotorName} idle';

    return Container(
      padding: const EdgeInsets.all(14),
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
        if (d.ugCmdFailed && !d.ugCmdSending) ...[
          _NotDeliveredBanner(onDismiss: d.onUgClearFailed),
          const SizedBox(height: 10),
        ],
        Row(children: [
          Icon(Icons.water_drop_outlined, color: color, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Underground · ${_stateLabel(state)}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor(context), fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(sub,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: labelColor(context), fontSize: 10.5)),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: subtleBg(context),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 11),
          _PowerButton(
            motorOn: motorOn, onOn: d.onUgOn, onOff: d.onUgOff,
            buzzer: d.ugBuzzer, sending: d.ugCmdSending, cd: cd, compact: true,
          ),
        ]),
        if (d.ugBuzzer && !d.ugCmdSending) ...[
          const SizedBox(height: 9),
          _CountdownBar(seconds: cd, color: kOrange),
        ],
      ]),
    );
  }
}
