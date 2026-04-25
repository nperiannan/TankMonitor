import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'tank_service.dart';
import 'login_screen.dart';
import 'setup_screen.dart';
import 'dashboard_screen.dart';
import 'claim_screen.dart';
import 'admin_screen.dart';

const _bg     = Color(0xFF141414);
const _cardBg = Color(0xFF1f1f1f);
const _cardBd = Color(0xFF303030);
const _label  = Color(0xFF8c8c8c);
const _blue   = Color(0xFF1890ff);
const _green  = Color(0xFF52c41a);
const _red    = Color(0xFFff4d4f);
const _orange = Color(0xFFfa8c16);

class DeviceListScreen extends StatefulWidget {
  /// When [autoNavigate] is true (default), a single device skips straight
  /// to the dashboard on load — useful for the initial app launch flow.
  /// Set to false when navigating here intentionally (e.g. "Switch device")
  /// so the user can see and manage their device cards.
  const DeviceListScreen({super.key, this.autoNavigate = true});

  final bool autoNavigate;

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  List<Device> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final svc = context.read<TankService>();
    final devices = await svc.listDevices();
    if (!mounted) return;

    // Auto-navigate when there's exactly one device — only on initial launch
    if (widget.autoNavigate && devices.length == 1) {
      await svc.connectToDevice(devices.first);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
      return;
    }
    setState(() { _devices = devices; _loading = false; });
  }

  Future<void> _selectDevice(Device d) async {
    final svc = context.read<TankService>();
    await svc.connectToDevice(d);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _rename(Device d) async {
    final nameCtrl = TextEditingController(text: d.displayName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Rename device', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Display name',
            hintStyle: const TextStyle(color: _label),
            filled: true, fillColor: const Color(0xFF262626),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _cardBd)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _cardBd)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _blue, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rename', style: TextStyle(color: _blue)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final newName = nameCtrl.text.trim();
    if (newName.isEmpty || newName == d.displayName) return;
    final svc = context.read<TankService>();
    final ok = await svc.renameDevice(d.mac, newName);
    if (!mounted) return;
    if (ok) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(svc.error ?? 'Rename failed')),
      );
    }
  }

  Future<void> _unclaim(Device d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBg,
        title: const Text('Remove device?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove "${d.displayName}" from your account?',
          style: const TextStyle(color: _label, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final svc = context.read<TankService>();
    final ok = await svc.unclaimDevice(d.mac);
    if (!mounted) return;
    if (ok) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(svc.error ?? 'Remove failed')),
      );
    }
  }

  void _logout() async {
    final svc = context.read<TankService>();
    await svc.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<TankService>();
    if (svc.unauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      });
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('💧 My Devices',
            style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (svc.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: _orange, size: 22),
              tooltip: 'Admin: Users & Devices',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: _label, size: 20),
            tooltip: 'Server settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: _label, size: 20),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _blue,
        tooltip: 'Claim device',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ClaimScreen()),
          );
          _load(); // refresh after returning
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _deviceCard(_devices[i]),
                  ),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.devices_other, size: 64, color: _label),
          const SizedBox(height: 16),
          const Text('No devices yet',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Tap + to claim your first device',
              style: TextStyle(color: _label, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _deviceCard(Device d) {
    return GestureDetector(
      onTap: () => _selectDevice(d),
      onLongPress: () => _showDeviceOptions(d),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border.all(color: _cardBd),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.memory, color: d.online ? _green : _label, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.displayName.isNotEmpty ? d.displayName : d.mac,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: d.online
                              ? const Color(0xFF162312)
                              : const Color(0xFF262626),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: d.online
                                  ? const Color(0xFF274916)
                                  : const Color(0xFF434343)),
                        ),
                        child: Text(
                          d.online ? '● Online' : '○ Offline',
                          style: TextStyle(
                              color: d.online ? _green : _label, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(d.mac,
                      style: const TextStyle(
                          color: _label, fontSize: 11, fontFamily: 'monospace')),
                  if (d.fwVersion.isNotEmpty)
                    Text('FW ${d.fwVersion}',
                        style: const TextStyle(color: _label, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _label, size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeviceOptions(Device d) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Text(
                d.displayName.isNotEmpty ? d.displayName : d.mac,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            const Divider(color: _cardBd, height: 1),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline, color: Colors.white),
              title: const Text('Rename', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(context); _rename(d); },
            ),
            ListTile(
              leading: const Icon(Icons.link_off, color: _red),
              title: const Text('Remove from account', style: TextStyle(color: _red)),
              onTap: () { Navigator.pop(context); _unclaim(d); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
