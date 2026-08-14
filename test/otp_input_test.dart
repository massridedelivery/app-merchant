import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/widgets/otp_input.dart';

void main() {
  Widget wrap(Widget child, {double width = 360}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  testWidgets('defaults to 6 boxes and completes only at 6 digits',
      (tester) async {
    String? completed;
    var changes = 0;

    await tester.pumpWidget(wrap(OtpInput(
      onChanged: (_) => changes++,
      onCompleted: (v) => completed = v,
    )));

    // 6 visual boxes by default.
    expect(find.byType(Container), findsNWidgets(6));

    // Five digits: not complete yet.
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(completed, isNull);

    // Sixth digit completes.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    expect(completed, '123456');

    // A 7th digit is rejected by the length limiter.
    await tester.enterText(find.byType(TextField), '1234567');
    await tester.pump();
    expect(find.text('7'), findsNothing);

    expect(changes, greaterThan(0));
  });

  testWidgets('renders 6 boxes on a narrow phone width without overflow',
      (tester) async {
    await tester.pumpWidget(wrap(const OtpInput(), width: 320));
    await tester.pump();

    // No layout overflow exception was thrown.
    expect(tester.takeException(), isNull);
    expect(find.byType(Container), findsNWidgets(6));
  });
}
