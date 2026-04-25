import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';

const _bg     = Color(0xFF141414);
const _cardBg = Color(0xFF1f1f1f);
const _cardBd = Color(0xFF303030);
const _label  = Color(0xFF8c8c8c);
const _blue   = Color(0xFF1890ff);
const _green  = Color(0xFF52c41a);
const _orange = Color(0xFFfa8c16);

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = context.read<TankService>();
    final users = await svc.adminListUsers();
    if (!mounted) return;
    setState(() { _users = users; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        title: const Text(
          '👥 Users & Devices',
          style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _label, size: 20),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Text('No users found',
                      style: TextStyle(color: _label, fontSize: 15)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _userCard(_users[i]),
                  ),
                ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? '—';
    final isAdmin  = user['is_admin'] as bool? ?? false;
    final devices  = (user['devices'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBd),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        collapsedBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        iconColor: _label,
        collapsedIconColor: _label,
        leading: CircleAvatar(
          backgroundColor: isAdmin
              ? const Color(0xFF391085)
              : const Color(0xFF003a8c),
          radius: 18,
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isAdmin) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF391085),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF531DAB)),
                ),
                child: const Text('admin',
                    style: TextStyle(color: _orange, fontSize: 10)),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            devices.isEmpty
                ? 'No devices claimed'
                : '${devices.length} device${devices.length == 1 ? '' : 's'}',
            style: const TextStyle(color: _label, fontSize: 12),
          ),
        ),
        children: devices.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Text('No devices claimed',
                      style: TextStyle(color: _label, fontSize: 13)),
                ),
              ]
            : devices.map((d) => _deviceRow(d)).toList(),
      ),
    );
  }

  Widget _deviceRow(Map<String, dynamic> d) {
    final name      = (d['display_name'] as String? ?? '').isNotEmpty
        ? d['display_name'] as String
        : d['mac'] as String? ?? '—';
    final mac       = d['mac'] as String? ?? '—';
    final fw        = d['fw_version'] as String? ?? '';
    final online    = d['online'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBd),
      ),
      child: Row(
        children: [
          Icon(Icons.memory, color: online ? _green : _label, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF162312)
                            : const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: online
                                ? const Color(0xFF274916)
                                : const Color(0xFF434343)),
                      ),
                      child: Text(
                        online ? '● Online' : '○ Offline',
                        style: TextStyle(
                            color: online ? _green : _label, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(mac,
                    style: const TextStyle(
                        color: _label,
                        fontSize: 10,
                        fontFamily: 'monospace')),
                if (fw.isNotEmpty)
                  Text('FW $fw',
                      style: const TextStyle(color: _label, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
