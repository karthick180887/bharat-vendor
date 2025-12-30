import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vendor_app/main.dart';

void main() {
  testWidgets('VendorApp builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const VendorApp());

    expect(find.byType(VendorApp), findsOneWidget);
    expect(find.byType(AuthWrapper), findsOneWidget);
  });
}
