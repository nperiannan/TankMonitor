import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';
import 'login_screen.dart';
import 'setup_screen.dart';
import 'device_list_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TankService(),
      child: const TankMonitorApp(),
    ),
  );
}

class TankMonitorApp extends StatelessWidget {
  const TankMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tank Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF1890ff)),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF1890ff) : null),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? const Color(0xFF1890ff).withOpacity(0.4) : null),
        ),
      ),
      home: const _Startup(),
    );
  }
}

/// Loads the saved token on first frame and routes to the right screen.
/// Token missing  → LoginScreen
/// Token present, no saved URL → SetupScreen
/// Token present, URL saved → DeviceListScreen (auto-navigates to Dashboard for single device)
class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  bool _ready = false;
  Widget _home = const _Splash();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final svc = context.read<TankService>();
    await svc.loadToken();
    if (svc.authToken == null) {
      setState(() { _home = const LoginScreen(); _ready = true; });
      return;
    }
    await svc.loadSavedUrls();
    if (svc.wifiUrl.isNotEmpty || svc.mobileUrl.isNotEmpty) {
      setState(() { _home = const DeviceListScreen(); _ready = true; });
    } else {
      setState(() { _home = const SetupScreen(); _ready = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const _Splash();
    return _home;
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF141414),
      body: Center(child: Text('💧', style: TextStyle(fontSize: 48))),
    );
  }
}
