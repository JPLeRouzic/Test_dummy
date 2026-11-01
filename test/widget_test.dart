import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:medquest/app.dart';

void main() {
  testWidgets('MedQuest opens on the dashboard', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MedQuestApp()));
    await tester.pumpAndSettle();

    expect(find.text('MedQuest'), findsOneWidget);
    expect(find.text('Bonjour !'), findsOneWidget);
    expect(find.text('Questions'), findsOneWidget);
  });
}
