import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/client.dart';
import 'package:flutter_application_1/widgets/client_card.dart';

void main() {
  testWidgets('client card indicates location without exposing coordinates',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ClientCard(
          client: Client(
            id: '1',
            name: 'Sam',
            lat: 51.5074,
            lng: -0.1278,
            createdAt: DateTime.utc(2026),
            queueNumber: 1,
          ),
        ),
      ),
    ));

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('Location context captured'), findsOneWidget);
    expect(find.textContaining('51.5074'), findsNothing);
    expect(find.textContaining('-0.1278'), findsNothing);
  });
}
