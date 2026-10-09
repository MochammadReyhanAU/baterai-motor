import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/bms_link.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'ui/connect_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState(Storage());
  await state.init();
  runApp(ChangeNotifierProvider.value(value: state, child: const BateraiMotorApp()));
  // Pratinjau web: ?demo=parked|riding|charging langsung membuka mode demo.
  final demo = kIsWeb ? Uri.base.queryParameters['demo'] : null;
  if (demo != null) {
    state.startDemo(DemoScenario.values.firstWhere((e) => e.name == demo, orElse: () => DemoScenario.parked));
  } else {
    state.autoConnect();
  }
}

class BateraiMotorApp extends StatelessWidget {
  const BateraiMotorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baterai Motor',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final hasLink = context.select<AppState, bool>((s) => s.linkState != LinkState.idle);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: hasLink ? const HomeShell() : const ConnectScreen(),
    );
  }
}
