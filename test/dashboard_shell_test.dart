import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:personal_monitor_mobile/screens/dashboard_screen.dart';
import 'package:personal_monitor_mobile/services/auth_service.dart';
import 'package:personal_monitor_mobile/widgets/app_drawer.dart';

void main() {
  testWidgets('dashboard keeps an accessible navigation drawer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const DashboardScreen(),
        ),
      ),
    );

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppDrawer), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppDrawer), matching: find.text('Finance')),
      findsOneWidget,
    );

    // Dashboard and drawer bootstrap network-backed data with timeouts.
    // Dispose them, then advance the fake clock to let those timeouts finish.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 11));
  });
}
