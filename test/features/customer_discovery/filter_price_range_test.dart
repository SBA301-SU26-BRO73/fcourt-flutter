import 'package:fcourt/src/features/customer_discovery/presentation/widgets/filter_price_range.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'price slider uses entered bounds, including prices above common presets',
    (tester) async {
      String? selectedMin, selectedMax;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPriceRange(
              minPrice: '',
              maxPrice: '',
              onChanged: (min, max) {
                selectedMin = min;
                selectedMax = max;
              },
            ),
          ),
        ),
      );
      expect(find.byType(RangeSlider), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Giá từ'),
        '25000000',
      );
      await tester.pump();
      expect(find.byType(RangeSlider), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Giá đến'),
        '90000000.12',
      );
      await tester.pump();
      final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      expect(slider.min, 25000000);
      expect(slider.max, 90000000.12);
      final rect = tester.getRect(find.byType(RangeSlider));
      await tester.dragFrom(
        Offset(rect.left + 24, rect.center.dy),
        Offset(rect.width * .2, 0),
      );
      await tester.pump();
      expect(double.parse(selectedMin!), greaterThan(25000000));
      expect(double.parse(selectedMax!), lessThanOrEqualTo(90000000.12));
      expect(tester.takeException(), isNull);
    },
  );
}
