import 'dart:ui';

import 'package:fcourt/features/catalog/presentation/formatters.dart';
import 'package:fcourt/features/catalog/presentation/messages.dart';
import 'package:fcourt/features/catalog/presentation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVnd', () {
    test('ngăn cách hàng nghìn bằng dấu chấm và thêm ký hiệu ₫', () {
      expect(formatVnd(0), '0 ₫');
      expect(formatVnd(999), '999 ₫');
      expect(formatVnd(1000), '1.000 ₫');
      expect(formatVnd(199000), '199.000 ₫');
      expect(formatVnd(1990000), '1.990.000 ₫');
      expect(formatVnd(1234567890), '1.234.567.890 ₫');
    });

    test('null nghĩa là không bán, có thể đổi nhãn', () {
      expect(formatVnd(null), 'Không bán');
      expect(formatVnd(null, whenNull: '-'), '-');
    });

    test('số âm giữ dấu trừ', () {
      expect(formatVnd(-1500), '-1.500 ₫');
    });
  });

  group('parseHexColor', () {
    test('đọc #RRGGBB và RRGGBB, luôn đục hoàn toàn', () {
      expect(parseHexColor('#0B7A4B'), const Color(0xFF0B7A4B));
      expect(parseHexColor('ff0000'), const Color(0xFFFF0000));
      expect(parseHexColor('  #00ff00 '), const Color(0xFF00FF00));
    });

    test('sai định dạng thì null', () {
      expect(parseHexColor(null), isNull);
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor('#GGGGGG'), isNull);
      expect(parseHexColor('red'), isNull);
    });
  });

  group('CatalogValidators', () {
    test('required: bắt buộc và giới hạn độ dài', () {
      expect(CatalogValidators.required(null, 'tên'), 'Vui lòng nhập tên');
      expect(CatalogValidators.required('   ', 'tên'), 'Vui lòng nhập tên');
      expect(CatalogValidators.required('a' * 101, 'tên', max: 100), 'tên tối đa 100 ký tự');
      expect(CatalogValidators.required(' ok ', 'tên', max: 100), isNull);
    });

    test('optionalText: để trống được, nhưng không vượt giới hạn', () {
      expect(CatalogValidators.optionalText('', 'Mô tả', 5), isNull);
      expect(CatalogValidators.optionalText('abcde', 'Mô tả', 5), isNull);
      expect(CatalogValidators.optionalText('abcdef', 'Mô tả', 5), 'Mô tả tối đa 5 ký tự');
    });

    test('optionalPrice: để trống là không bán, nhập thì phải là số nguyên không âm', () {
      expect(CatalogValidators.optionalPrice('', 'Giá'), isNull);
      expect(CatalogValidators.optionalPrice(null, 'Giá'), isNull);
      expect(CatalogValidators.optionalPrice('0', 'Giá'), isNull);
      expect(CatalogValidators.optionalPrice('199000', 'Giá'), isNull);
      expect(CatalogValidators.optionalPrice('abc', 'Giá'), 'Giá phải là số nguyên');
      expect(CatalogValidators.optionalPrice('1.5', 'Giá'), 'Giá phải là số nguyên');
      expect(CatalogValidators.optionalPrice('-1', 'Giá'), 'Giá không được âm');
    });

    test('positiveInt: bắt buộc và từ 1 trở lên', () {
      expect(CatalogValidators.positiveInt('', 'Số sân'), 'Vui lòng nhập Số sân');
      expect(CatalogValidators.positiveInt('x', 'Số sân'), 'Số sân phải là số nguyên');
      expect(CatalogValidators.positiveInt('0', 'Số sân'), 'Số sân phải từ 1 trở lên');
      expect(CatalogValidators.positiveInt('1', 'Số sân'), isNull);
    });

    test('positiveInt: không vượt Integer của BE (2147483647)', () {
      expect(CatalogValidators.positiveInt('2147483647', 'Số sân'), isNull);
      expect(
        CatalogValidators.positiveInt('2147483648', 'Số sân'),
        'Số sân tối đa 2147483647',
      );
    });

    test('parseFeatures: bỏ dòng trống, cắt khoảng trắng, bỏ trùng, giữ thứ tự', () {
      expect(
        CatalogValidators.parseFeatures('  A \n\nB\nA\n   \n C'),
        ['A', 'B', 'C'],
      );
      expect(CatalogValidators.parseFeatures(null), isEmpty);
      expect(CatalogValidators.parseFeatures(''), isEmpty);
    });

    test('features: tối đa 30 tính năng, mỗi tính năng tối đa 255 ký tự', () {
      expect(CatalogValidators.features(List.generate(30, (i) => 'f$i').join('\n')), isNull);
      expect(
        CatalogValidators.features(List.generate(31, (i) => 'f$i').join('\n')),
        'Tối đa 30 tính năng',
      );
      expect(CatalogValidators.features('a' * 256), 'Mỗi tính năng tối đa 255 ký tự');
      expect(CatalogValidators.features('a' * 255), isNull);
    });

    test('blankToNull và parsePrice', () {
      expect(CatalogValidators.blankToNull('  '), isNull);
      expect(CatalogValidators.blankToNull(null), isNull);
      expect(CatalogValidators.blankToNull(' x '), 'x');
      expect(CatalogValidators.parsePrice(' 199000 '), 199000);
      expect(CatalogValidators.parsePrice(''), isNull);
      expect(CatalogValidators.parsePrice(null), isNull);
    });
  });

  group('CatalogMessages', () {
    test('đổi các lỗi BE đã biết sang tiếng Việt', () {
      expect(CatalogMessages.localize('Court type name already exists'), 'Tên loại sân đã tồn tại');
      expect(
        CatalogMessages.localize('Subscription plan name already exists'),
        'Tên gói dịch vụ đã tồn tại',
      );
      expect(
        CatalogMessages.localize('You are not allowed to perform this action'),
        'Bạn không có quyền thực hiện thao tác này',
      );
    });

    test('lỗi chưa biết giữ nguyên, localizeAll giữ tên field', () {
      expect(CatalogMessages.localize('something new'), 'something new');
      expect(
        CatalogMessages.localizeAll({'name': 'Court type name already exists', 'icon': 'raw'}),
        {'name': 'Tên loại sân đã tồn tại', 'icon': 'raw'},
      );
    });
  });
}
