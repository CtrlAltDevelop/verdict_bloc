import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdict_bloc_example/main.dart';

/// Drives both samples end to end. A spinner animates forever, so these use
/// explicit `pump(duration)` rather than `pumpAndSettle`.
void main() {
  testWidgets('the profile sample loads, saves and reports', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Profile form'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Ada Lovelace'), findsOneWidget);

    // First save succeeds.
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Profile saved.'), findsOneWidget);

    // Second save fails — and the form is still on screen behind the report.
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('That email is already in use.'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ada@example.com'), findsOne);
  });

  testWidgets('local validation reports without touching the api', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.text('Profile form'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('That does not look like an email address.'),
      findsOneWidget,
    );
  });

  testWidgets('the list sample loads a first page', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await tester.tap(find.text('Paginated list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Items (100)'), findsOneWidget);
  });
}
