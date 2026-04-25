import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';

const _bg     = Color(0xFF141414);
const _cardBg = Color(0xFF1f1f1f);
const _cardBd = Color(0xFF303030);
const _label  = Color(0xFF8c8c8c);
const _blue   = Color(0xFF1890ff);
const _red    = Color(0xFFff4d4f);

class ClaimScreen extends StatefulWidget {
  const ClaimScreen({super.key});

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _macCtrl  = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading  = false;
  String? _error;

  @override
  void dispose() {
    _macCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final mac  = _macCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    if (mac.isEmpty || name.isEmpty) {
      setState(() => _error = 'MAC address and device name are required');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final svc = context.read<TankService>();
    final ok = await svc.claimDevice(mac, name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = svc.error ?? 'Failed to claim device';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        leading: BackButton(color: _label.withOpacity(0.8)),
        title: const Text('Claim Device',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a device to your account by entering its MAC address.',
              style: TextStyle(color: _label, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can find the MAC address on the device LCD screen or physical label.',
              style: TextStyle(color: _label, fontSize: 13),
            ),
            const SizedBox(height: 24),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1215),
                  border: Border.all(color: const Color(0xFF58181C)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: _red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: _red, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            const Text('MAC address', style: TextStyle(color: _label, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _macCtrl,
              decoration: _inputDec('e.g. AA:BB:CC:DD:EE:FF', Icons.memory_outlined),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 16),

            const Text('Device name', style: TextStyle(color: _label, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: _inputDec('e.g. Rooftop Tank', Icons.label_outline),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _claim(),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _claim,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Claim Device', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _label),
        prefixIcon: Icon(icon, color: _label, size: 20),
        filled: true,
        fillColor: const Color(0xFF1f1f1f),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _cardBd)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _cardBd)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _blue, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
