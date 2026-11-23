import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/app_connectivity.dart';
import 'package:flutter_application_1/widgets/offline_banner.dart';

void main() {
  testWidgets('shows a clear banner when the device is offline', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: OfflineBanner(status: AppConnectivity.offline)),
    ));
    expect(find.text('No network connection'), findsOneWidget);
  });
}
