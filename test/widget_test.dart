import 'package:flutter_test/flutter_test.dart';
import 'package:focus_app/main.dart';
import 'package:provider/provider.dart';
import 'package:focus_app/services/ble_service.dart';

void main() {
  testWidgets('App startet ohne Crash', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BleService(),
        child: const FocusSenseApp(),
      ),
    );
    expect(find.text('FOCUS-Sense'), findsOneWidget);
  });
}
