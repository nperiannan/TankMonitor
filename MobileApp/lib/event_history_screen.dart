import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';
import 'theme_data.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen> {
  List<Map<String, dynamic>> _records = [];
  int _totalCount = 0;
  bool _loading = true;
  String _filter = 'ALL'; // ALL, OH, UG, MOTOR, BOOT

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.read<TankService>();

    setState(() => _loading = true);
    final data = await svc.fetchHistory();
    if (!mounted) return;
    setState(() {
      _records = (data['records'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      _totalCount = data['count'] as int? ?? 0;
      _loading = false;
    });
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
        case 'MOTOR': return ev.startsWith('MOTOR_');
        case 'BOOT':  return ev == 'BOOT';
        default:      return true;
      }
    }).toList();
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
                _buildFilterBar(),
                Expanded(child: _buildEventList()),
              ],
            ),
    );
  }

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
    final events = _filtered;
    if (events.isEmpty) {
      return Center(
        child: Text('No events', style: TextStyle(color: labelColor(context), fontSize: 14)),
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in events) {
      final time = r['time'] as String? ?? '';
      // time format: "HH:MM AM DD-MM-YYYY" — extract date part
      final parts = time.split(' ');
      final date = parts.length >= 3 ? parts.last : 'Unknown';
      grouped.putIfAbsent(date, () => []).add(r);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: grouped.length,
        itemBuilder: (context, groupIdx) {
          final date = grouped.keys.elementAt(groupIdx);
          final items = grouped[date]!;
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
                  children: List.generate(items.length, (i) {
                    final r = items[i];
                    final ev = r['ev'] as String? ?? '';
                    final time = r['time'] as String? ?? '';
                    // Extract just the time portion (e.g. "10:45 AM")
                    final timeParts = time.split(' ');
                    final timeStr = timeParts.length >= 2
                        ? '${timeParts[0]} ${timeParts[1]}'
                        : time;

                    return Column(
                      children: [
                        if (i > 0) Divider(height: 1, color: cardBd(context)),
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: _eventIcon(ev),
                          title: Text(_eventLabel(ev),
                              style: TextStyle(color: textColor(context), fontSize: 13)),
                          subtitle: _eventSubtitle(r),
                          trailing: Text(timeStr,
                              style: TextStyle(color: labelColor(context), fontSize: 11)),
                        ),
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

  Widget _eventIcon(String ev) {
    IconData icon;
    Color color;
    if (ev.startsWith('MOTOR_') && ev.endsWith('_ON')) {
      icon = Icons.flash_on;
      color = kGreen;
    } else if (ev.startsWith('MOTOR_') && ev.endsWith('_OFF')) {
      icon = Icons.flash_off;
      color = kRed;
    } else if (ev.startsWith('TANK_')) {
      icon = Icons.water_drop;
      color = kBlue;
    } else if (ev == 'BOOT') {
      icon = Icons.restart_alt;
      color = kOrange;
    } else {
      icon = Icons.circle;
      color = labelColor(context);
    }
    return Icon(icon, color: color, size: 20);
  }

  String _eventLabel(String ev) {
    switch (ev) {
      case 'MOTOR_OH_ON':   return 'OH Motor ON';
      case 'MOTOR_OH_OFF':  return 'OH Motor OFF';
      case 'MOTOR_UG_ON':   return 'UG Motor ON';
      case 'MOTOR_UG_OFF':  return 'UG Motor OFF';
      case 'BOOT':          return 'System Boot';
      default:
        // Tank state changes: "TANK_OH_FULL", "TANK_UG_LOW", etc.
        if (ev.startsWith('TANK_')) {
          final parts = ev.replaceFirst('TANK_', '').split('_');
          if (parts.length >= 2) {
            return '${parts[0]} Tank → ${parts.sublist(1).join(' ')}';
          }
        }
        return ev;
    }
  }

  Widget? _eventSubtitle(Map<String, dynamic> r) {
    final ev = r['ev'] as String? ?? '';
    final oh = r['oh'] as String? ?? '';
    final ug = r['ug'] as String? ?? '';
    final ohM = r['ohM'] as bool? ?? false;
    final ugM = r['ugM'] as bool? ?? false;

    if (ev == 'BOOT') return null;

    final parts = <String>[];
    if (oh.isNotEmpty) parts.add('OH:$oh');
    if (ug.isNotEmpty) parts.add('UG:$ug');
    if (ohM) parts.add('OH Motor ON');
    if (ugM) parts.add('UG Motor ON');

    if (parts.isEmpty) return null;
    return Text(parts.join(' • '),
        style: TextStyle(color: labelColor(context), fontSize: 11));
  }
}
