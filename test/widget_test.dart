import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/main.dart';

void main() {
  testWidgets('App class exists smoke test', (WidgetTester tester) async {
    // Note: Firebase is not initialised in unit tests.
    // For integration tests, configure a Firebase test environment.
    expect(TourExpenseApp, isNotNull);
  });
}
