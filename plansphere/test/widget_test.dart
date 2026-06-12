import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plansphere/main.dart';

void main() {
  testWidgets('App test', (WidgetTester tester) async {
    await tester.pumpWidget(const PlanSphereApp());
  });
}