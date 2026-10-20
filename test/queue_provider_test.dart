import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/queue_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('QueueProvider initial state is empty', () {
    // Basic unit test to verify provider initializes without crashing
    final provider = QueueProvider();
    expect(provider.clients.isEmpty, true);
  });
}