import 'package:flutter_test/flutter_test.dart';
import 'package:pacehealth/main.dart';
import 'package:pacehealth/state/profile_store.dart';

void main() {
  testWidgets('shows the login page to signed-out users', (WidgetTester tester) async {
    await tester.pumpWidget(PaceHealthApp(store: ProfileStore()));

    expect(find.text('Welcome to PaceHealth'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
