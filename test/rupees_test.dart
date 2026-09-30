import 'package:flutter_test/flutter_test.dart';
import 'package:temple_trust/core/widgets.dart';

void main() {
  test('paise read as rupees, grouped the Indian way', () {
    expect(rupees(12345600), '₹1,23,456.00');
    expect(rupees(5050), '₹50.50');
    expect(rupees(null), '₹0.00');
  });
}
