import 'package:flutter_test/flutter_test.dart';
import 'package:personal_monitor_mobile/services/scripture_reference_service.dart';

void main() {
  const service = ScriptureReferenceService();

  test('Christianity gratitude returns 3-5 Bible references', () {
    final refs = service.forTopic(
      'gratitude',
      faithPath: 'Christianity',
    );

    expect(refs.length, inInclusiveRange(3, 5));
    expect(refs.every((ref) => ref.reference.isNotEmpty), isTrue);
    expect(refs.every((ref) => ref.text.isNotEmpty), isTrue);
  });

  test('Christianity falls back to general references for unknown topic', () {
    final refs = service.forTopic(
      'morning routine planning',
      faithPath: 'Christianity',
    );

    expect(refs.length, inInclusiveRange(3, 5));
  });

  test('Non-Christian faith returns no Bible references', () {
    final refs = service.forTopic(
      'gratitude',
      faithPath: 'Islam',
    );

    expect(refs, isEmpty);
  });
}
