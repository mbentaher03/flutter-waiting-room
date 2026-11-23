import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/queue_provider.dart';

void main() {
  test('should add a client to the waiting list', () {
    // ARRANGE
    final manager = QueueProvider();

    // ACT
    manager.addClient('John Doe');

    // ASSERT
    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'John Doe');
  });

  test('should remove a client from the waiting list', () {
    // ARRANGE
    final manager = QueueProvider();

    manager.addClient('client A');
    manager.addClient('client B');

    // ACT
    manager.removeClient('client A');

    // ASSERT
    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'client B');
  });
  test('should remove the first client when nextClient() is called', () {
  // ARRANGE
  final manager = QueueProvider();

  manager.addClient('Client A');
  manager.addClient('Client B');

  // ACT
  manager.nextClient();

  // ASSERT
  expect(manager.clients.length, 1);
  expect(manager.clients.first, 'Client B');
});
}