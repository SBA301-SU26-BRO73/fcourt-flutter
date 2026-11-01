import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/catalog/domain/entities/court_type_input.dart';
import 'package:fcourt/features/catalog/presentation/bloc/catalog_form_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const input = CourtTypeInput(name: 'Cầu lông');

  blocTest<CatalogFormBloc<CourtTypeInput>, CatalogFormState>(
    'lưu thành công thì submitting rồi success, và chuyển đúng dữ liệu form',
    build: () {
      final saved = <CourtTypeInput>[];
      return CatalogFormBloc<CourtTypeInput>((value) async => saved.add(value));
    },
    act: (bloc) => bloc.add(const CatalogFormSubmitted(input)),
    expect: () => [const CatalogFormState.submitting(), const CatalogFormState.success()],
  );

  test('hàm lưu nhận đúng input của form', () async {
    CourtTypeInput? received;
    final bloc = CatalogFormBloc<CourtTypeInput>((value) async => received = value);

    bloc.add(const CatalogFormSubmitted(input));
    await bloc.stream.firstWhere((state) => state.status == CatalogFormStatus.success);

    expect(received, input);
    await bloc.close();
  });

  blocTest<CatalogFormBloc<CourtTypeInput>, CatalogFormState>(
    'tên trùng thì failure kèm lý do của BE',
    build: () => CatalogFormBloc<CourtTypeInput>(
      (_) async => throw const ServerFailure('Court type name already exists', statusCode: 409),
    ),
    act: (bloc) => bloc.add(const CatalogFormSubmitted(input)),
    expect: () => [
      const CatalogFormState.submitting(),
      const CatalogFormState.failure('Court type name already exists'),
    ],
  );

  blocTest<CatalogFormBloc<CourtTypeInput>, CatalogFormState>(
    'lỗi validation theo field được chuyển cho form',
    build: () => CatalogFormBloc<CourtTypeInput>(
      (_) async => throw const ServerFailure(
        'Invalid request fields',
        statusCode: 400,
        fieldErrors: {'name': 'name is required'},
      ),
    ),
    act: (bloc) => bloc.add(const CatalogFormSubmitted(input)),
    expect: () => [
      const CatalogFormState.submitting(),
      const CatalogFormState.failure(
        'Invalid request fields',
        fieldErrors: {'name': 'name is required'},
      ),
    ],
  );

  blocTest<CatalogFormBloc<CourtTypeInput>, CatalogFormState>(
    'không phải super admin hoặc mất mạng thì failure với thông báo của lỗi đó',
    build: () => CatalogFormBloc<CourtTypeInput>((_) async => throw const NetworkFailure()),
    act: (bloc) => bloc.add(const CatalogFormSubmitted(input)),
    expect: () => [
      const CatalogFormState.submitting(),
      const CatalogFormState.failure('Không kết nối được máy chủ'),
    ],
  );

  test('gửi hai lần liên tiếp chỉ gọi hàm lưu một lần', () async {
    var calls = 0;
    final bloc = CatalogFormBloc<CourtTypeInput>((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    bloc
      ..add(const CatalogFormSubmitted(input))
      ..add(const CatalogFormSubmitted(input));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(calls, 1);
    await bloc.close();
  });
}
