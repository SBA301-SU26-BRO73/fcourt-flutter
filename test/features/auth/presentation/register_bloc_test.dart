import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/auth/domain/entities/upload_document.dart';
import 'package:fcourt/features/auth/domain/usecases/register_court_owner.dart';
import 'package:fcourt/features/auth/domain/usecases/register_customer.dart';
import 'package:fcourt/features/auth/presentation/bloc/register_bloc.dart';
import 'package:fcourt/features/auth/presentation/bloc/submission_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  const legal = [UploadDocument(name: 'licence.pdf', path: '/tmp/licence.pdf')];
  const images = [UploadDocument(name: 'front.jpg', path: '/tmp/front.jpg')];
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  RegisterBloc build() =>
      RegisterBloc(RegisterCustomer(repository), RegisterCourtOwner(repository));

  const customerEvent = CustomerRegistrationSubmitted(
    fullName: 'An Nguyen',
    email: 'customer@demo.com',
    phone: '0909000001',
    password: 'S3cret-pass',
  );

  const ownerEvent = OwnerRegistrationSubmitted(
    fullName: 'Chu San',
    email: 'owner@demo.com',
    phone: '0909000003',
    password: 'S3cret-pass',
    legalDocuments: legal,
    courtImages: images,
  );

  group('khách hàng', () {
    blocTest<RegisterBloc, SubmissionState>(
      'đăng ký thành công thì success kèm người dùng đã đăng nhập',
      setUp: () => when(
        () => repository.registerCustomer(
          fullName: 'An Nguyen',
          email: 'customer@demo.com',
          phone: '0909000001',
          password: 'S3cret-pass',
        ),
      ).thenAnswer((_) async => customerUser),
      build: build,
      act: (bloc) => bloc.add(customerEvent),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.success(customerUser),
      ],
    );

    blocTest<RegisterBloc, SubmissionState>(
      'email trùng thì failure kèm thông báo của BE',
      setUp: () => when(
        () => repository.registerCustomer(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const ServerFailure('Email is already registered', statusCode: 409)),
      build: build,
      act: (bloc) => bloc.add(customerEvent),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure('Email is already registered'),
      ],
    );

    blocTest<RegisterBloc, SubmissionState>(
      'lỗi validation theo field được chuyển cho form',
      setUp: () => when(
        () => repository.registerCustomer(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ServerFailure(
          'Invalid request fields',
          statusCode: 400,
          fieldErrors: {'phone': 'phone must be a Vietnamese phone number such as 0909000001'},
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(customerEvent),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure(
          'Invalid request fields',
          fieldErrors: {'phone': 'phone must be a Vietnamese phone number such as 0909000001'},
        ),
      ],
    );
  });

  group('chủ sân', () {
    blocTest<RegisterBloc, SubmissionState>(
      'gửi hồ sơ thành công thì success không có người dùng (chờ duyệt)',
      setUp: () => when(
        () => repository.registerCourtOwner(
          fullName: 'Chu San',
          email: 'owner@demo.com',
          phone: '0909000003',
          password: 'S3cret-pass',
          legalDocuments: legal,
          courtImages: images,
        ),
      ).thenAnswer((_) async {}),
      build: build,
      act: (bloc) => bloc.add(ownerEvent),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.success(),
      ],
      verify: (bloc) => expect(bloc.state.user, isNull),
    );

    blocTest<RegisterBloc, SubmissionState>(
      'kho tài liệu lỗi thì failure để người dùng thử lại',
      setUp: () => when(
        () => repository.registerCourtOwner(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
          legalDocuments: any(named: 'legalDocuments'),
          courtImages: any(named: 'courtImages'),
        ),
      ).thenThrow(const ServerFailure('Document storage is unavailable', statusCode: 503)),
      build: build,
      act: (bloc) => bloc.add(ownerEvent),
      expect: () => [
        const SubmissionState.submitting(),
        const SubmissionState.failure('Document storage is unavailable'),
      ],
    );

    blocTest<RegisterBloc, SubmissionState>(
      'gửi hai lần liên tiếp chỉ gọi BE một lần',
      setUp: () => when(
        () => repository.registerCourtOwner(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
          legalDocuments: any(named: 'legalDocuments'),
          courtImages: any(named: 'courtImages'),
        ),
      ).thenAnswer((_) => Future<void>.delayed(const Duration(milliseconds: 10))),
      build: build,
      act: (bloc) {
        bloc.add(ownerEvent);
        bloc.add(ownerEvent);
      },
      wait: const Duration(milliseconds: 50),
      verify: (_) => verify(
        () => repository.registerCourtOwner(
          fullName: any(named: 'fullName'),
          email: any(named: 'email'),
          phone: any(named: 'phone'),
          password: any(named: 'password'),
          legalDocuments: any(named: 'legalDocuments'),
          courtImages: any(named: 'courtImages'),
        ),
      ).called(1),
    );
  });
}
