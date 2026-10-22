import 'package:flutter_test/flutter_test.dart';
import 'package:unimarket/models/models.dart';

void main() {
  final start = DateTime(2026, 10, 6);
  test('return date is exclusive; dates cross month/year without drift', () {
    expect(rentalDays(start, DateTime(2026, 10, 7)), 1);
    expect(rentalDays(DateTime(2026, 12, 31), DateTime(2027, 1, 2)), 2);
    expect(rentalDays(DateTime(2026, 10, 6, 23), DateTime(2026, 10, 7, 1)), 1);
  });
  test('purchase and daily rental totals use correct pricing and rounding', () {
    expect(
      bookingTotal(
        mode: 'buy',
        salePrice: 300,
        dailyRate: 15,
        start: start,
        end: start,
      ),
      300,
    );
    expect(
      bookingTotal(
        mode: 'rent',
        salePrice: 300,
        dailyRate: 19.99,
        start: start,
        end: start.add(const Duration(days: 3)),
      ),
      59.97,
    );
  });
  test(
    'reject unsupported types, unavailable pricing and rental periods outside 1-90 days',
    () {
      for (final days in [-1, 0, 91]) {
        expect(
          () => bookingTotal(
            mode: 'rent',
            salePrice: 300,
            dailyRate: 10,
            start: start,
            end: start.add(Duration(days: days)),
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => bookingTotal(
          mode: 'buy',
          salePrice: 0,
          dailyRate: 10,
          start: start,
          end: start,
        ),
        throwsArgumentError,
      );
      expect(
        () => bookingTotal(
          mode: 'anything',
          salePrice: 300,
          dailyRate: 10,
          start: start,
          end: start,
        ),
        throwsArgumentError,
      );
    },
  );
}
