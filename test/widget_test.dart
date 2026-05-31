import 'package:flutter_test/flutter_test.dart';

import 'package:csac/main.dart';

void main() {
  testWidgets('shows localized CsAC splash on startup', (tester) async {
    await tester.pumpWidget(const CsacMobileApp());
    await tester.pump();

    expect(find.text('CsAC 移动端'), findsOneWidget);
  });
}
