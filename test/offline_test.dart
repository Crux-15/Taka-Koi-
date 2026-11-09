import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/utils/app_exception.dart';
import 'package:tour_expense_tracker/utils/offline.dart';

void main() {
  const wait = Duration(milliseconds: 50);

  group('saveOrQueue', () {
    test('true when the server confirms in time', () async {
      expect(await saveOrQueue(Future<void>.value(), 'test', wait: wait), isTrue);
    });

    test('false (queued) instead of spinning when the server never answers', () async {
      final never = Completer<void>().future; // like a write made offline
      final sw = Stopwatch()..start();
      expect(await saveOrQueue(never, 'test', wait: wait), isFalse);
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('a refusal that arrives in time is passed on', () async {
      final refused = Future<void>.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await expectLater(saveOrQueue(refused, 'test', wait: wait), throwsA(isA<FirebaseException>()));
    });

    test('a failure after the wait is logged, not thrown into the app', () async {
      final late = Completer<void>();
      expect(await saveOrQueue(late.future, 'test', wait: wait), isFalse);
      late.completeError(StateError('rejected after sync'));
      await Future<void>.delayed(Duration.zero); // would surface as an uncaught error if unhandled
    });
  });

  test('inBackground swallows and logs failures', () async {
    inBackground(Future<void>.error(StateError('notification failed')), 'test');
    await Future<void>.delayed(Duration.zero);
  });

  group('friendlyError', () {
    test('offline and slow connections get plain messages', () {
      expect(friendlyError(FirebaseException(plugin: 'x', code: 'unavailable'), 'f'), offlineMessage);
      expect(friendlyError(TimeoutException('t'), 'f'), slowConnectionMessage);
      expect(friendlyError(FirebaseException(plugin: 'x', code: 'deadline-exceeded'), 'f'), slowConnectionMessage);
    });

    test('app errors keep their own message; anything else gets the fallback', () {
      expect(friendlyError(const AppException('Already approved.'), 'f'), 'Already approved.');
      expect(friendlyError(StateError('boom'), 'Something went wrong'), 'Something went wrong');
    });
  });
}
