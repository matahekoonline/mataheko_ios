import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mataheko/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MatahekoApp());
    expect(find.text('Mataheko-Afienya'), findsOneWidget);
  });
}