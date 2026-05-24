import 'package:flutter_test/flutter_test.dart';

import 'package:csac/main.dart';

void main() {
  testWidgets('shows CsAC splash on startup', (tester) async {
    await tester.pumpWidget(const CsacMobileApp());

    expect(find.text('CsAC Mobile'), findsOneWidget);
  });
}
