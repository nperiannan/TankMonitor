import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';
import 'models.dart';
import 'theme_data.dart';

// Accent colours are theme-independent (they read well on light & dark).
const _purple = Color(0xFF7C4DFF);
const _runFg = Color(0xFF08130A);

/// A single motor run built from an ON event and its following OFF (or null if
/// the motor is still running).
class _Run {
  final String motor; // 'OH' | 'UG'
  final Map<String, dynamic> on;
  final Map<String, dynamic>? off;
  _Run({required this.motor, required this.on, this.off});
  int get onTs => on['ts'] as int? ?? 0;
  int? get offTs => off?['ts'] as int?;
  bool get running => off == null;
  String get reason => (on['rsnStr'] as String?) ?? '';
  int durSec(int nowTs) {
    final end = offTs ?? nowTs;
    final d = end - onTs;
    return d < 0 ? 0 : d;
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class EventHistoryScreen extends StatefulWidget {
  final bool initialGraph;
  const EventHistoryScreen({super.key, this.initialGraph = false});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  int _totalCount = 0;
  bool _loading = true;
  bool _showGraph = false;

  // Theme-aware colour accessors (match the rest of the app, follow light/dark).
  Color get _bg => scaffoldBg(context);
  Color get _card => cardBg(context);
  Color get _card2 => subtleBg(context);
  Color get _bd => cardBd(context);
  Color get _txt => textColor(context);
  Color get _lbl => labelColor(context);
  Color get _green => accentGreen(context);
  Color get _blue => accentBlue(context);
  Color get _orange => kOrange;
  Color get _red => accentRed(context);

  @override
  void initState() {
    super.initState();
    _showGraph = widget.initialGraph;
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    final svc = context.read<TankService>();
    if (showSpinner) setState(() => _loading = true);
    final data = await svc.fetchHistory(triggerRefresh: showSpinner);
    if (!mounted) return;
    setState(() {
      _records = (data['records'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _totalCount = data['count'] as int? ?? _records.length;
      _loading = false;
    });
    if (showSpinner) {
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted) _load(showSpinner: false);
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text('Clear all history?', style: TextStyle(color: _txt, fontSize: 16)),
        content: Text('This will erase all $_totalCount events.', style: TextStyle(color: _lbl, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Clear', style: TextStyle(color: _red))),
        ],
      ),
    );
    if (confirm != true) return;
    final svc = context.read<TankService>();
    await svc.clearHistory();
    if (mounted) await _load();
  }

  // ── Pair ON/OFF events into runs (newest-first) ──────────────────────────
  List<_Run> _runs() {
    final chrono = _records.reversed.toList(); // oldest-first
    Map<String, dynamic>? openOH, openUG;
    final runs = <_Run>[];
    for (final r in chrono) {
      switch (r['ev'] as String? ?? '') {
        case 'OH Motor ON':
          openOH = r;
          break;
        case 'OH Motor OFF':
          if (openOH != null) runs.add(_Run(motor: 'OH', on: openOH, off: r));
          openOH = null;
          break;
        case 'UG Motor ON':
          openUG = r;
          break;
        case 'UG Motor OFF':
          if (openUG != null) runs.add(_Run(motor: 'UG', on: openUG, off: r));
          openUG = null;
          break;
      }
    }
    if (openOH != null) runs.add(_Run(motor: 'OH', on: openOH, off: null));
    if (openUG != null) runs.add(_Run(motor: 'UG', on: openUG, off: null));
    runs.sort((a, b) => b.onTs.compareTo(a.onTs)); // newest first
    return runs;
  }

  int _nowTs() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String _two(int n) => n.toString().padLeft(2, '0');
  String _hhmm(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    return '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _durLong(int sec) {
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60, h = m ~/ 60, mm = m % 60;
    return h > 0 ? '${h}h ${_two(mm)}m' : '${m}m';
  }

  String _durShort(int sec) {
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60, h = m ~/ 60, mm = m % 60;
    return h > 0 ? '${h}h ${mm}m' : '${m}m';
  }

  String _dayKey(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    return '${d.year}-${d.month}-${d.day}';
  }

  String _dayHeader(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    final now = DateTime.now();
    final diff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    final base = '${d.day} ${_months[d.month - 1]}'.toUpperCase();
    if (diff == 0) return 'TODAY · $base';
    if (diff == 1) return 'YESTERDAY · $base';
    return base;
  }

  ({String text, Color color}) _reason(_Run r) {
    final s = r.reason.toLowerCase();
    if (s.contains('manual')) {
      if (s.contains('touch') || s.contains('controller')) return (text: 'Manual · Controller', color: _blue);
      if (s.contains('web')) return (text: 'Manual · Web', color: _blue);
      if (s.contains('app')) return (text: 'Manual · App', color: _blue);
      return (text: 'Manual', color: _blue);
    }
    if (s.contains('schedul')) return (text: 'Scheduled', color: _orange);
    if (s.contains('full')) return (text: 'Auto · Tank full', color: _green);
    if (s.contains('auto') || s.contains('level')) return (text: 'Auto · Level', color: _green);
    if (s.contains('max')) return (text: 'Max runtime', color: _red);
    if (s.contains('lora') || s.contains('signal')) return (text: 'Signal lost', color: _red);
    if (s.contains('power restore')) return (text: 'Power restored', color: _green);
    if (s.contains('power')) return (text: 'Power cut', color: _red);
    if (r.reason.isEmpty) return (text: 'Auto', color: _green);
    return (text: r.reason, color: _orange);
  }

  @override
  Widget build(BuildContext context) {
    final runs = _runs();
    final issues = context.watch<TankService>().deliveryIssues;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: BackButton(color: _lbl),
        titleSpacing: 0,
        title: Text('History', style: TextStyle(color: _txt, fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: _red, size: 20),
            onPressed: runs.isEmpty ? null : _clearHistory,
            tooltip: 'Clear history',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: _green))
          : RefreshIndicator(
              color: _green,
              backgroundColor: _card,
              onRefresh: () => _load(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (issues.isNotEmpty) ...[
                    _deliveryIssuesCard(issues),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _bd),
                    ),
                    child: Column(children: [
                      _headerRow(),
                      const SizedBox(height: 12),
                      if (_showGraph) _graphView(runs) else _tableView(runs),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }

  // ── DELIVERY ISSUES card (local, unacknowledged commands) ────────────────
  Widget _deliveryIssuesCard(List<DeliveryIssue> issues) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.error_outline, color: _red, size: 18),
            const SizedBox(width: 6),
            Text('DELIVERY ISSUES',
                style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            const Spacer(),
            GestureDetector(
              onTap: () => context.read<TankService>().clearDeliveryIssues(),
              child: Text('CLEAR',
                  style: TextStyle(color: _red.withOpacity(0.85), fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Commands the controller never acknowledged (no ack received).',
              style: TextStyle(color: _lbl, fontSize: 11)),
          const SizedBox(height: 10),
          ...issues.map(_deliveryIssueRow),
        ],
      ),
    );
  }

  Widget _deliveryIssueRow(DeliveryIssue e) {
    final d = e.time.toLocal();
    final dateStr = '${d.day} ${_months[d.month - 1]} · ${_two(d.hour)}:${_two(d.minute)}';
    final label = '${e.motor} motor ${e.start ? 'start' : 'stop'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _red.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.wifi_off_rounded, color: _red, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(color: _txt, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text('Not delivered — signal did not reach the controller',
                  style: TextStyle(color: _lbl, fontSize: 10.5)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(dateStr,
            style: TextStyle(color: _lbl, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _headerRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('HISTORY',
              style: TextStyle(color: _lbl, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(9)),
            child: Row(children: [
              _toggleBtn('Table', !_showGraph, () => setState(() => _showGraph = false)),
              _toggleBtn('Graph', _showGraph, () => setState(() => _showGraph = true)),
            ]),
          ),
        ],
      );

  Widget _toggleBtn(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: on ? _blue : Colors.transparent, borderRadius: BorderRadius.circular(7)),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : _lbl,
                  fontSize: 11,
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400)),
        ),
      );

  Widget _stat(String v, String k, Color? vColor) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text(v, style: TextStyle(color: vColor ?? _txt, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(k, textAlign: TextAlign.center, style: TextStyle(color: _lbl, fontSize: 8.5, letterSpacing: 0.4)),
          ]),
        ),
      );

  Widget _empty(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 44),
        child: Center(child: Text(msg, style: TextStyle(color: _lbl, fontSize: 14))),
      );

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(t, style: TextStyle(color: _lbl, fontSize: 10)),
      ]);

  // ── TABLE (T1★ Enhanced) ─────────────────────────────────────────────────
  Widget _tableView(List<_Run> runs) {
    if (runs.isEmpty) return _empty('No motor runs yet');
    final nowTs = _nowTs();
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);

    int runsToday = 0, ohSec = 0, ugSec = 0, maxDur = 1;
    for (final r in runs) {
      final d = DateTime.fromMillisecondsSinceEpoch(r.onTs * 1000).toLocal();
      final dur = r.durSec(nowTs);
      if (dur > maxDur) maxDur = dur;
      if (DateTime(d.year, d.month, d.day) == t0) {
        runsToday++;
        if (r.motor == 'OH') {
          ohSec += dur;
        } else {
          ugSec += dur;
        }
      }
    }

    final groups = <String, List<_Run>>{};
    final order = <String>[];
    for (final r in runs) {
      final k = _dayKey(r.onTs);
      if (!groups.containsKey(k)) {
        groups[k] = [];
        order.add(k);
      }
      groups[k]!.add(r);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _stat('$runsToday', 'RUNS TODAY', null),
        const SizedBox(width: 8),
        _stat(_durLong(ohSec + ugSec), 'TOTAL RUN', null),
        const SizedBox(width: 8),
        _stat(_durShort(ohSec), 'OH · UG ${_durShort(ugSec)}', _green),
      ]),
      for (final k in order) ...[
        _dateHeader(groups[k]!, nowTs),
        for (final r in groups[k]!) _runRow(r, maxDur, nowTs),
      ],
    ]);
  }

  Widget _dateHeader(List<_Run> dayRuns, int nowTs) {
    final subtotal = dayRuns.fold<int>(0, (a, r) => a + r.durSec(nowTs));
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_dayHeader(dayRuns.first.onTs),
            style: TextStyle(color: _lbl, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        Text('${dayRuns.length} runs · ${_durLong(subtotal)}', style: TextStyle(color: _lbl, fontSize: 10)),
      ]),
    );
  }

  Widget _runRow(_Run r, int maxDur, int nowTs) {
    final isOH = r.motor == 'OH';
    final c = isOH ? _green : _purple;
    final dur = r.durSec(nowTs);
    final rsn = _reason(r);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _bd))),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Container(width: 3, height: 36, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _motorChip(r.motor, c),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: r.running ? '${_hhmm(r.onTs)} → ' : '${_hhmm(r.onTs)} → ${_hhmm(r.offTs!)}',
                        style: TextStyle(color: _txt, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    if (r.running)
                      TextSpan(text: 'now', style: TextStyle(color: _green, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 4),
            r.running ? _pill('● RUNNING', _green, solid: true, bold: true) : _pill(rsn.text, rsn.color),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (dur / maxDur).clamp(0.02, 1.0),
                minHeight: 4,
                backgroundColor: _card2,
                color: c,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text(_durShort(dur), style: TextStyle(color: r.running ? _green : _txt, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _motorChip(String m, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12), border: Border.all(color: c), borderRadius: BorderRadius.circular(6)),
        child: Text(m, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)),
      );

  Widget _pill(String text, Color color, {bool solid = false, bool bold = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
        decoration:
            BoxDecoration(color: solid ? color : color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: solid ? _runFg : color, fontSize: 9, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      );

  // ── GRAPH (G2★ Enhanced) ─────────────────────────────────────────────────
  Widget _graphView(List<_Run> runs) {
    if (runs.isEmpty) return _empty('No motor runs to chart yet');
    final nowTs = _nowTs();
    final chrono = runs.reversed.toList(); // oldest-first
    final show = chrono.length > 12 ? chrono.sublist(chrono.length - 12) : chrono;

    final durs = show.map((r) => r.durSec(nowTs) / 60.0).toList(); // minutes
    int total = 0, longest = 0;
    for (final r in show) {
      final d = r.durSec(nowTs);
      total += d;
      if (d > longest) longest = d;
    }
    final avgMin = durs.isEmpty ? 0.0 : durs.reduce((a, b) => a + b) / durs.length;
    double maxDurMin = 0;
    for (final d in durs) {
      if (d > maxDurMin) maxDurMin = d;
    }
    final maxY = maxDurMin <= 0 ? 20.0 : (maxDurMin / 20).ceil() * 20.0;
    final step = maxY <= 80 ? 20.0 : (maxY / 4).ceilToDouble();
    final grids = <double>[];
    for (double v = step; v <= maxY + 0.1; v += step) {
      grids.add(v);
    }
    const plotH = 160.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        _stat(_durLong(total), 'TOTAL', null),
        const SizedBox(width: 8),
        _stat(_durShort(longest), 'LONGEST', null),
        const SizedBox(width: 8),
        _stat('${avgMin.round()}m', 'AVG', null),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _legend(_green, 'OH'),
        const SizedBox(width: 14),
        _legend(_purple, 'UG'),
        const Spacer(),
        Text('minutes', style: TextStyle(color: _lbl, fontSize: 10)),
      ]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 24,
          height: plotH,
          child: Stack(children: [
            for (final g in grids)
              Positioned(
                top: plotH * (1 - g / maxY) - 6,
                right: 4,
                child: Text(g.toInt().toString(), style: TextStyle(color: _lbl, fontSize: 8)),
              ),
          ]),
        ),
        Expanded(
          child: SizedBox(
            height: plotH,
            child: Stack(clipBehavior: Clip.none, children: [
              for (final g in grids)
                Positioned(top: plotH * (1 - g / maxY), left: 0, right: 0, child: _DashedLine(color: _bd)),
              if (avgMin > 0 && avgMin <= maxY)
                Positioned(
                  top: plotH * (1 - avgMin / maxY),
                  left: 0,
                  right: 0,
                  child: _DashedLine(color: _orange, label: 'avg ${avgMin.round()}', labelBg: _card),
                ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < show.length; i++)
                      Expanded(
                        child: _bar(
                          show[i],
                          durs[i],
                          maxY,
                          plotH,
                          dayStart: i > 0 && _dayKey(show[i].onTs) != _dayKey(show[i - 1].onTs),
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 5),
      Row(children: [
        const SizedBox(width: 24),
        Expanded(
          child: Row(children: [
            for (int i = 0; i < show.length; i++)
              Expanded(
                child: Column(children: [
                  if (i == 0 || _dayKey(show[i].onTs) != _dayKey(show[i - 1].onTs))
                    Text(_dateShort(show[i].onTs),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _txt, fontSize: 8, fontWeight: FontWeight.w600)),
                  Text(_hhmm(show[i].onTs), style: TextStyle(color: _lbl, fontSize: 8)),
                ]),
              ),
          ]),
        ),
      ]),
    ]);
  }

  String _dateShort(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    return '${d.day} ${_months[d.month - 1]}';
  }

  Widget _bar(_Run r, double durMin, double maxY, double plotH, {bool dayStart = false}) {
    final isOH = r.motor == 'OH';
    final grad = isOH
        ? const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5CFFA8), Color(0xFF00C853)])
        : const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB39DFF), Color(0xFF651FFF)]);
    final barH = (plotH * (durMin / maxY)).clamp(3.0, plotH - 18);
    return Container(
      decoration: dayStart ? BoxDecoration(border: Border(left: BorderSide(color: _bd))) : null,
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('${durMin.round()}',
            style: TextStyle(color: isOH ? _green : _purple, fontSize: 9, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        FractionallySizedBox(
          widthFactor: 0.62,
          child: Container(
            height: barH,
            decoration: BoxDecoration(gradient: grad, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
          ),
        ),
      ]),
    );
  }
}

/// Horizontal dashed line used for chart gridlines and the average marker.
class _DashedLine extends StatelessWidget {
  final Color color;
  final String? label;
  final Color? labelBg;
  const _DashedLine({required this.color, this.label, this.labelBg});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: Stack(clipBehavior: Clip.none, children: [
        CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter(color)),
        if (label != null)
          Positioned(
            right: 0,
            top: -13,
            child: Container(
              color: labelBg,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(label!, style: TextStyle(color: color, fontSize: 8)),
            ),
          ),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), p);
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
