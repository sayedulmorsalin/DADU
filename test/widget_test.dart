import 'package:dadu/component/home_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home skeleton smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeFullSkeleton(),
        ),
      ),
    );
    expect(find.byType(HomeFullSkeleton), findsOneWidget);
    expect(find.byType(ProductCardSkeleton), findsWidgets);
  });
}
