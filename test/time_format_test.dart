import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_trust/core/widgets.dart';

void main() {
  test('times are shown on the 12-hour clock', () {
    expect(showTime('05:30'), '5:30 AM');
    expect(showTime('17:30:00'), '5:30 PM');
    expect(showTime('12:00'), '12:00 PM');
    expect(showTime('00:15'), '12:15 AM');
    expect(showTime(const TimeOfDay(hour: 21, minute: 5)), '9:05 PM');
    expect(showTime(null), isNull);
    // A label already written for people is left as it is.
    expect(showTime('9:00 – 10:00 AM'), '9:00 – 10:00 AM');
  });

  test('the API still gets HH:mm', () {
    expect(formatTime(const TimeOfDay(hour: 17, minute: 30)), '17:30');
  });
}
