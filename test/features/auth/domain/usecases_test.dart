import 'package:fcourt/features/auth/domain/entities/upload_document.dart';
import 'package:fcourt/features/auth/domain/usecases/login.dart';
import 'package:fcourt/features/auth/domain/usecases/logout.dart';
import 'package:fcourt/features/auth/domain/usecases/register_court_owner.dart';
import 'package:fcourt/features/auth/domain/usecases/register_customer.dart';
import 'package:fcourt/features/auth/domain/usecases/restore_session.dart';
import 'package:fcourt/features/auth/domain/usecases/update_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  test('Login bỏ khoảng trắng thừa quanh email nhưng giữ nguyên mật khẩu', () async {
    when(() => repository.login(email: 'customer@demo.com', password: ' pass '))
        .thenAnswer((_) async => customerUser);

    final user = await Login(repository)(email: '  customer@demo.com ', password: ' pass ');

    expect(user, customerUser);
  });

  test('RegisterCustomer cắt khoảng trắng các trường văn bản', () async {
    when(
      () => repository.registerCustomer(
        fullName: 'An Nguyen',
        email: 'customer@demo.com',
        phone: '0909000001',
        password: 'S3cret-pass',
      ),
    ).thenAnswer((_) async => customerUser);

    final user = await RegisterCustomer(repository)(
      fullName: ' An Nguyen ',
      email: ' customer@demo.com ',
      phone: ' 0909000001 ',
      password: 'S3cret-pass',
    );

    expect(user, customerUser);
  });

  test('RegisterCourtOwner chuyển hồ sơ và tệp cho repository', () async {
    const legal = [UploadDocument(name: 'licence.pdf', path: '/tmp/licence.pdf')];
    const images = [UploadDocument(name: 'front.jpg', path: '/tmp/front.jpg')];
    when(
      () => repository.registerCourtOwner(
        fullName: 'Chu San',
        email: 'owner@demo.com',
        phone: '0909000003',
        password: 'S3cret-pass',
        legalDocuments: legal,
        courtImages: images,
      ),
    ).thenAnswer((_) async {});

    await RegisterCourtOwner(repository)(
      fullName: ' Chu San ',
      email: 'owner@demo.com ',
      phone: '0909000003',
      password: 'S3cret-pass',
      legalDocuments: legal,
      courtImages: images,
    );

    verify(
      () => repository.registerCourtOwner(
        fullName: 'Chu San',
        email: 'owner@demo.com',
        phone: '0909000003',
        password: 'S3cret-pass',
        legalDocuments: legal,
        courtImages: images,
      ),
    ).called(1);
  });

  test('RestoreSession trả người dùng hoặc null từ repository', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => customerUser);
    expect(await RestoreSession(repository)(), customerUser);

    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    expect(await RestoreSession(repository)(), isNull);
  });

  test('UpdateProfile cắt khoảng trắng họ tên và số điện thoại', () async {
    when(() => repository.updateProfile(fullName: 'New Name', phone: '0911222333'))
        .thenAnswer((_) async => customerUser);

    final user = await UpdateProfile(repository)(fullName: ' New Name ', phone: ' 0911222333 ');

    expect(user, customerUser);
  });

  test('Logout gọi repository', () async {
    when(() => repository.logout()).thenAnswer((_) async {});

    await Logout(repository)();

    verify(() => repository.logout()).called(1);
  });
}
