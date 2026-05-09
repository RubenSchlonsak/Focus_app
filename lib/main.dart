import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/device_screen.dart';
import 'screens/scan_screen.dart';
import 'services/ble_service.dart';
import 'services/recording_service.dart';
import 'services/study_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BleService()),
        ChangeNotifierProvider(create: (_) => StudyManager()..init()),
        ChangeNotifierProvider(create: (_) => RecordingService()),
      ],
      child: const FocusSenseApp(),
    ),
  );
}

class FocusSenseApp extends StatelessWidget {
  const FocusSenseApp({super.key});

  static const _cyan = Color(0xFF00E5CC);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FOCUS-Sense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: _cyan,
          secondary: Color(0xFF00BCD4),
          surface: Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF12121F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: _cyan,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E2E),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _cyan,
            foregroundColor: Colors.black87,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _cyan,
            side: const BorderSide(color: _cyan),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? _cyan : Colors.grey,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? _cyan.withAlpha(128)
                : Colors.grey.withAlpha(77),
          ),
        ),
        sliderTheme: const SliderThemeData(activeTrackColor: _cyan, thumbColor: _cyan),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          selectedItemColor: _cyan,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const _AppNavigator(),
    );
  }
}

class _AppNavigator extends StatelessWidget {
  const _AppNavigator();

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (_, ble, _) =>
          ble.isConnected ? const DeviceScreen() : const ScanScreen(),
    );
  }
}
