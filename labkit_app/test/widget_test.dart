import 'package:flutter_test/flutter_test.dart';

import 'package:labkit_app/labs/lab1.dart';

void main() {
  test('Lab 1 has 27 steps and ends with the summary', () {
    expect(lab1.steps.length, 27);
    expect(lab1.steps.last.title, contains('Lab 1 done'));
  });
}
