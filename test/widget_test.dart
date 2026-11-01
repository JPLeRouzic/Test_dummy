import 'package:anatomo/widgets/logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logo and wordmark draw', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [AnatomoMark(size: 64), AnatomoWordmark()],
          ),
        ),
      ),
    );
    expect(find.byType(AnatomoMark), findsOneWidget);
    expect(find.byType(AnatomoWordmark), findsOneWidget);
  });
}
