import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';
import 'theme_data.dart';

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
  String _filter = 'ALL'; // ALL, OH, UG, MOTOR, BOOT

  @override
  void initState() {
    super.initState();
    _showGraph = widget.initialGraph;
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    final svc = context.read<TankService>();

    if (showSpinner) setState(() => _loading = true);
    // Fast path: read persisted history straight from the backend DB. On the
    // initial load we also trigger the device to republish; a moment later we
    // silently re-read to pick up any brand-new events.
    final data = await svc.fetchHistory(triggerRefresh: showSpinner);
    if (!mounted) return;
    setState(() {
      _records = (data['records'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
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
        backgroundColor: cardBg(ctx),
        title: Text('Clear all history?',
            style: TextStyle(color: textColor(ctx), fontSize: 16)),
        content: Text('This will erase all $_totalCount events from the EEPROM.',
            style: TextStyle(color: labelColor(ctx), fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final svc = context.read<TankService>();
    await svc.clearHistory();
    if (mounted) await _load();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'ALL') return _records;
    return _records.where((r) {
      final ev = r['ev'] as String? ?? '';
      switch (_filter) {
        case 'OH':    return ev.contains('OH');
        case 'UG':    return ev.contains('UG');
        case 'MOTOR': return ev.contains('Motor');
        case 'BOOT':  return ev == 'Boot';
        default:      return true;
      }
    }).toList();
  }

  // Merge each motor ON with its following OFF into a single "run" item.
  // Returns newest-first display items: {run:true, motor, on, off} or {run:false, r}.
  List<Map<String, dynamic>> _pairRecords(List<Map<String, dynamic>> recs) {
    final chrono = recs.reversed.toList(); // oldest-first
    Map<String, dynamic>? openOH, openUG;
    final items = <Map<String, dynamic>>[];
    for (final r in chrono) {
      final ev = r['ev'] as String? ?? '';
      if (ev == 'OH Motor ON') {
        openOH = r;
      } else if (ev == 'OH Motor OFF') {
        items.add({'run': true, 'motor': 'OH', 'on': openOH, 'off': r});
        openOH = null;
      } else if (ev == 'UG Motor ON') {
        openUG = r;
      } else if (ev == 'UG Motor OFF') {
        items.add({'run': true, 'motor': 'UG', 'on': openUG, 'off': r});
        openUG = null;
      } else {
        items.add({'run': false, 'r': r});
      }
    }
    if (openOH != null) items.add({'run': true, 'motor': 'OH', 'on': openOH, 'off': null});
    if (openUG != null) items.add({'run': true, 'motor': 'UG', 'on': openUG, 'off': null});
    return items.reversed.toList(); // newest-first
  }

  String _fmtDur(int sec) {
    if (sec <= 0) return '';
    if (sec < 60) return '${sec}s';
    final m = sec ~/ 60, s = sec % 60;
    return s > 0 ? '${m}m ${s}s' : '${m}m';
  }

  String _shortTime(String t) {
    final p = t.split(' ');
    return p.length >= 2 ? '${p[0]} ${p[1]}' : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: cardBg(context),
        elevation: 0,
        leading: BackButton(color: labelColor(context)),
        title: Text('Event History',
            style: TextStyle(color: textColor(context), fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
            onPressed: _records.isEmpty ? null : _clearHistory,
            tooltip: 'Clear history',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildViewToggle(),
                if (!_showGraph) _buildFilterBar(),
                Expanded(child: _showGraph ? _buildGraph() : _buildEventList()),
              ],
            ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      color: cardBg(context),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Table'), icon: Icon(Icons.table_rows, size: 16)),
          ButtonSegment(value: true, label: Text('Trend Graph'), icon: Icon(Icons.show_chart, size: 16)),
        ],
        selected: {_showGraph},
        onSelectionChanged: (s) => setState(() => _showGraph = s.first),
        showSelectedIcon: false,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  /// Individual motor runs: {ts (start epoch), dur (minutes), motor}.
  List<Map<String, dynamic>> _runList() {
    final runs = _pairRecords(_records).where((it) => it['run'] == true);
    final out = <Map<String, dynamic>>[];
    for (final it in runs) {
      final on = it['on'] as Map<String, dynamic>?;
      final off = it['off'] as Map<String, dynamic>?;
      if (on == null || off == null) continue;
      final onTs = on['ts'] as int? ?? 0;
      final offTs = off['ts'] as int? ?? 0;
      final durMin = (offTs - onTs) / 60.0;
      if (durMin <= 0 || onTs <= 0) continue;
      out.add({'ts': onTs, 'dur': durMin, 'motor': it['motor'] as String});
    }
    out.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
    return out;
  }

  String _fmtAxisTime(double x, {bool multiDay = true}) {
    final d = DateTime.fromMillisecondsSinceEpoch(x.toInt() * 1000).toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return multiDay ? '${d.day}/${d.month}\n$hh:$mm' : '$hh:$mm';
  }

  Widget _buildGraph() {
    final runs = _runList();
    if (runs.isEmpty) {
      return Center(
        child: Text('No motor runs to chart yet', style: TextStyle(color: labelColor(context), fontSize: 14)),
      );
    }
    final ohColor = accentGreen(context);
    const ugColor = Color(0xFF7c4dff);
    double minX = (runs.first['ts'] as int).toDouble();
    double maxX = (runs.last['ts'] as int).toDouble();
    double maxY = 0;
    for (final r in runs) {
      if ((r['dur'] as double) > maxY) maxY = r['dur'] as double;
    }
    if (maxX <= minX) maxX = minX + 3600; // avoid a zero-width span
    final pad = (maxX - minX) * 0.05;
    minX -= pad;
    maxX += pad;
    maxY = maxY <= 0 ? 5 : maxY * 1.2;
    final multiDay = (maxX - minX) > 86400;

    final spots = runs.map((r) {
      final c = (r['motor'] == 'OH') ? ohColor : ugColor;
      return ScatterSpot(
        (r['ts'] as int).toDouble(),
        r['dur'] as double,
        dotPainter: FlDotCirclePainter(color: c, radius: 5),
      );
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Motor runs — duration over time',
              style: TextStyle(color: textColor(context), fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            _legendDot(ohColor, 'OH'),
            const SizedBox(width: 14),
            _legendDot(ugColor, 'UG'),
            const Spacer(),
            Text('y = minutes', style: TextStyle(color: labelColor(context), fontSize: 10)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: ScatterChart(
              ScatterChartData(
                minX: minX, maxX: maxX, minY: 0, maxY: maxY,
                scatterSpots: spots,
                scatterTouchData: ScatterTouchData(
                  enabled: true,
                  touchTooltipData: ScatterTouchTooltipData(
                    getTooltipItems: (spot) {
                      final d = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt() * 1000).toLocal();
                      final hh = d.hour.toString().padLeft(2, '0');
                      final mm = d.minute.toString().padLeft(2, '0');
                      return ScatterTooltipItem(
                        '${d.day}/${d.month} $hh:$mm\n${spot.y.toStringAsFixed(1)} min',
                        textStyle: TextStyle(color: textColor(context), fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    axisNameWidget: Text('min', style: TextStyle(color: labelColor(context), fontSize: 9)),
                    axisNameSize: 14,
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 30, interval: (maxY / 4).ceilToDouble(),
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: TextStyle(color: labelColor(context), fontSize: 9)),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: multiDay ? 34 : 24,
                      interval: (maxX - minX) / 4,
                      getTitlesWidget: (v, _) {
                        if (v <= minX || v >= maxX) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_fmtAxisTime(v, multiDay: multiDay),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: labelColor(context), fontSize: 8)),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: true,
                    getDrawingHorizontalLine: (_) => FlLine(color: cardBd(context), strokeWidth: 0.5),
                    getDrawingVerticalLine: (_) => FlLine(color: cardBd(context), strokeWidth: 0.3)),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: labelColor(context), fontSize: 11)),
      ]);

  Widget _buildFilterBar() {
    return Container(
      color: cardBg(context),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final f in ['ALL', 'OH', 'UG', 'MOTOR', 'BOOT'])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(f, style: const TextStyle(fontSize: 11)),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: accentBlue(context).withValues(alpha: 0.3),
                backgroundColor: cardBd(context),
                labelStyle: TextStyle(
                  color: _filter == f ? accentBlue(context) : labelColor(context),
                  fontWeight: _filter == f ? FontWeight.bold : FontWeight.normal,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const Spacer(),
          Text('${_filtered.length} / $_totalCount',
              style: TextStyle(color: labelColor(context), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final items = _pairRecords(_filtered);
    if (items.isEmpty) {
      return Center(
        child: Text('No events', style: TextStyle(color: labelColor(context), fontSize: 14)),
      );
    }

    // Group by date (from each display item's timestamp string)
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final it in items) {
      final time = _itemTime(it);
      final parts = time.split(' ');
      final date = parts.length >= 3 ? parts.last : 'Unknown';
      grouped.putIfAbsent(date, () => []).add(it);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: grouped.length,
        itemBuilder: (context, groupIdx) {
          final date = grouped.keys.elementAt(groupIdx);
          final rows = grouped[date]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
                child: Text(date, style: TextStyle(
                  color: labelColor(context), fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cardBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBd(context)),
                ),
                child: Column(
                  children: List.generate(rows.length, (i) {
                    final it = rows[i];
                    return Column(
                      children: [
                        if (i > 0) Divider(height: 1, color: cardBd(context)),
                        (it['run'] == true)
                            ? _runTile(it)
                            : _eventTile(it['r'] as Map<String, dynamic>),
                      ],
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _itemTime(Map<String, dynamic> it) {
    if (it['run'] == true) {
      final off = it['off'] as Map<String, dynamic>?;
      final on = it['on'] as Map<String, dynamic>?;
      return (off?['time'] ?? on?['time'] ?? '') as String;
    }
    return (it['r'] as Map<String, dynamic>)['time'] as String? ?? '';
  }

  Widget _runTile(Map<String, dynamic> it) {
    final motor = it['motor'] as String;
    final on = it['on'] as Map<String, dynamic>?;
    final off = it['off'] as Map<String, dynamic>?;
    final running = off == null;
    final onReason = ((on?['rsnStr'] as String? ?? '').isEmpty) ? '—' : on!['rsnStr'] as String;
    final offReason = running
        ? 'running'
        : (((off?['rsnStr'] as String? ?? '').isEmpty) ? '—' : off!['rsnStr'] as String);
    final dur = (on != null && off != null)
        ? _fmtDur((off['ts'] as int? ?? 0) - (on['ts'] as int? ?? 0))
        : '';
    final when = (on != null && off != null)
        ? '${_shortTime(on['time'] as String? ?? '')} → ${_shortTime(off['time'] as String? ?? '')}'
        : _shortTime(((off ?? on)?['time'] as String?) ?? '');
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Icon(running ? Icons.play_circle_fill : Icons.timelapse,
          color: running ? kGreen : accentBlue(context), size: 20),
      title: Text('$motor Motor${dur.isNotEmpty ? '  ($dur)' : ''}',
          style: TextStyle(color: textColor(context), fontSize: 13)),
      subtitle: Text('$onReason → $offReason',
          style: TextStyle(color: labelColor(context), fontSize: 11)),
      trailing: Text(when,
          style: TextStyle(color: labelColor(context), fontSize: 10)),
    );
  }

  Widget _eventTile(Map<String, dynamic> r) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: _eventIcon(r['ev'] as String? ?? ''),
      title: Text(_eventLabel(r),
          style: TextStyle(color: textColor(context), fontSize: 13)),
      subtitle: _eventSubtitle(r),
      trailing: Text(_shortTime(r['time'] as String? ?? ''),
          style: TextStyle(color: labelColor(context), fontSize: 11)),
    );
  }

  Widget _eventIcon(String ev) {
    IconData icon;
    Color color;
    if (ev.contains('Motor ON')) {
      icon = Icons.flash_on;
      color = kGreen;
    } else if (ev.contains('Motor OFF')) {
      icon = Icons.flash_off;
      color = kRed;
    } else if (ev.contains('State')) {
      icon = Icons.water_drop;
      color = kBlue;
    } else if (ev == 'Boot') {
      icon = Icons.restart_alt;
      color = kOrange;
    } else {
      icon = Icons.circle;
      color = labelColor(context);
    }
    return Icon(icon, color: color, size: 20);
  }

  String _eventLabel(Map<String, dynamic> r) {
    final ev = r['ev'] as String? ?? '';
    if (ev == 'Boot') return 'System Boot';
    if (ev == 'OH State') return 'OH Tank → ${r['oh'] ?? ''}';
    if (ev == 'UG State') return 'UG Tank → ${r['ug'] ?? ''}';
    return ev; // e.g. "OH Motor ON"
  }

  Widget? _eventSubtitle(Map<String, dynamic> r) {
    final ev = r['ev'] as String? ?? '';
    final rsn = r['rsnStr'] as String? ?? '';
    final oh = r['oh'] as String? ?? '';
    final ug = r['ug'] as String? ?? '';

    final parts = <String>[];
    if (rsn.isNotEmpty) parts.add(rsn);
    if (ev != 'Boot') {
      if (oh.isNotEmpty && oh != '?') parts.add('OH:$oh');
      if (ug.isNotEmpty && ug != '?') parts.add('UG:$ug');
    }

    if (parts.isEmpty) return null;
    return Text(parts.join(' • '),
        style: TextStyle(color: labelColor(context), fontSize: 11));
  }
}
