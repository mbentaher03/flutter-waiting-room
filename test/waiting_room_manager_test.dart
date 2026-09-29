import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/waiting_room_manager.dart';

void main() {
  test('should add a client to the waiting list', () {
    // ARRANGE
    final manager = WaitingRoomManager();

    // ACT
    manager.addClient('John Doe');

    // ASSERT
    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'John Doe');
  });
    test('should remove a client from the waiting list', () {
    // ARRANGE
    final manager = WaitingRoomManager();
    manager.addClient('John Doe');
    manager.addClient('Jane Doe');

    // ACT
    manager.removeClient('John Doe');

    // ASSERT
    expect(manager.clients.length, 1);
    expect(manager.clients.first, 'Jane Doe');
  });
}