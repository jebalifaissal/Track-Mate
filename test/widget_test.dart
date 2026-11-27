import 'package:delivery_boy_app/screen/commercial_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Track-Mate commercial dashboard renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommercialHomeScreen()));

    expect(find.text('Track-Mate'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Commandes'), findsOneWidget);
    expect(find.text('Suivi'), findsOneWidget);
  });

  testWidgets('role menu exposes customer and merchant spaces', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommercialHomeScreen()));

    await tester.tap(find.text('Livreur'));
    await tester.pumpAndSettle();

    expect(find.text('Espace client'), findsOneWidget);
    expect(find.text('Espace commerçant'), findsOneWidget);
    expect(find.text('Espace livreur'), findsOneWidget);
  });
}
