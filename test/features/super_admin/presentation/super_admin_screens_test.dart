import 'package:fcourt/app/app_dependencies.dart';
import 'package:fcourt/app/router.dart';
import 'package:fcourt/core/config/app_config.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/health/domain/entities/health_status.dart';
import 'package:fcourt/features/health/domain/repositories/health_repository.dart';
import 'package:fcourt/features/super_admin/domain/entities/court_owner.dart';
import 'package:fcourt/features/super_admin/domain/repositories/court_owner_approval_repository.dart';
import 'package:fcourt/features/super_admin/domain/usecases/owner_approval_usecases.dart';
import 'package:fcourt/features/super_admin/presentation/bloc/owner_detail_cubit.dart';
import 'package:fcourt/features/super_admin/presentation/pages/owner_approval_detail_screen.dart';
import 'package:fcourt/features/super_admin/presentation/widgets/owner_document_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeHealthRepository implements HealthRepository {
  @override
  Future<HealthStatus> check() async => const HealthStatus('ok');
}

/// Repository giả giữ trạng thái như backend: duyệt/từ chối đổi status và
/// hồ sơ biến mất khỏi danh sách chờ.
class FakeOwnerRepository implements CourtOwnerApprovalRepository {
  FakeOwnerRepository(List<CourtOwner> owners)
    : _owners = {for (final o in owners) o.id: o};

  final Map<int, CourtOwner> _owners;
  int pendingCalls = 0;
  final List<(int, String)> rejects = [];
  Failure? decisionFailure;

  void add(CourtOwner owner) => _owners[owner.id] = owner;

  @override
  Future<List<CourtOwner>> pendingOwners() async {
    pendingCalls++;
    return _owners.values.where((o) => o.isPending).toList();
  }

  @override
  Future<CourtOwner> ownerDetail(int ownerId) async => _owners[ownerId]!;

  @override
  Future<CourtOwner> approve(int ownerId, {String? reason}) async =>
      _decide(ownerId, OwnerStatus.active);

  @override
  Future<CourtOwner> reject(int ownerId, String reason) async {
    rejects.add((ownerId, reason));
    return _decide(ownerId, OwnerStatus.rejected);
  }

  CourtOwner _decide(int id, OwnerStatus status) {
    final failure = decisionFailure;
    if (failure != null) throw failure;
    final old = _owners[id]!;
    return _owners[id] = CourtOwner(
      id: id,
      email: old.email,
      fullName: old.fullName,
      status: status,
      documents: old.documents,
    );
  }
}

CourtOwner owner(
  int id, {
  OwnerStatus status = OwnerStatus.pendingApproval,
  List<OwnerDocument> documents = const [],
}) => CourtOwner(
  id: id,
  email: 'owner$id@fcourt.vn',
  fullName: 'Chủ sân $id',
  phone: '090000000$id',
  status: status,
  documents: documents,
);

Future<void> pumpRouterAt(
  WidgetTester tester,
  FakeOwnerRepository repository,
  String location,
) async {
  final router = createRouter(
    AppDependencies(
      config: const AppConfig(env: AppEnv.dev, apiBaseUrl: 'http://test'),
      healthRepository: _FakeHealthRepository(),
      courtOwnerApprovalRepository: repository,
    ),
  );
  router.go(location);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

Future<void> pumpDetail(WidgetTester tester, FakeOwnerRepository repository) {
  return tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => OwnerDetailCubit(
          ownerId: 1,
          getOwnerDetail: GetOwnerDetail(repository),
          approveOwner: ApproveOwner(repository),
          rejectOwner: RejectOwner(repository),
        )..load(),
        child: OwnerApprovalDetailScreen(
          imageBuilder: (_, url) => Text('image:${url.path}'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('danh sách chỉ hiển thị hồ sơ chờ duyệt', (tester) async {
    final repository = FakeOwnerRepository([
      owner(1),
      owner(2, status: OwnerStatus.active),
      owner(3),
    ]);

    await pumpRouterAt(tester, repository, '/super-admin/owners/pending');

    expect(find.text('Chủ sân 1'), findsOneWidget);
    expect(find.text('Chủ sân 3'), findsOneWidget);
    expect(find.text('Chủ sân 2'), findsNothing);
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('kéo xuống để tải lại danh sách', (tester) async {
    final repository = FakeOwnerRepository([owner(1)]);
    await pumpRouterAt(tester, repository, '/super-admin/owners/pending');
    expect(repository.pendingCalls, 1);

    repository.add(owner(4));
    await tester.fling(find.text('Chủ sân 1'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repository.pendingCalls, 2);
    expect(find.text('Chủ sân 4'), findsOneWidget);
  });

  testWidgets('danh sách rỗng hiển thị thông báo', (tester) async {
    await pumpRouterAt(
      tester,
      FakeOwnerRepository([]),
      '/super-admin/owners/pending',
    );

    expect(find.text('Không có hồ sơ nào chờ duyệt'), findsOneWidget);
  });

  testWidgets('duyệt hồ sơ: xóa khỏi danh sách ngay và hiện SnackBar', (
    tester,
  ) async {
    final repository = FakeOwnerRepository([owner(1), owner(2)]);
    await pumpRouterAt(tester, repository, '/super-admin/owners/pending');

    await tester.tap(find.text('Chủ sân 1'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết hồ sơ chủ sân'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
    await tester.pumpAndSettle();
    expect(find.text('Duyệt hồ sơ chủ sân?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ chủ sân chờ duyệt'), findsOneWidget);
    expect(find.text('Chủ sân 1'), findsNothing);
    expect(find.text('Chủ sân 2'), findsOneWidget);
    expect(find.text('Đã duyệt hồ sơ Chủ sân 1'), findsOneWidget);
    // Danh sách cập nhật ngay, không cần gọi lại API.
    expect(repository.pendingCalls, 1);
  });

  testWidgets('từ chối bắt buộc nhập lý do', (tester) async {
    final repository = FakeOwnerRepository([owner(1)]);
    await pumpRouterAt(tester, repository, '/super-admin/owners/pending');
    await tester.tap(find.text('Chủ sân 1'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập lý do từ chối'), findsOneWidget);
    expect(repository.rejects, isEmpty);

    await tester.enterText(
      find.byKey(const Key('owner-decision-reason')),
      '  Ảnh CCCD bị mờ  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
    await tester.pumpAndSettle();

    expect(repository.rejects, [(1, 'Ảnh CCCD bị mờ')]);
    expect(find.text('Chủ sân 1'), findsNothing);
    expect(find.text('Đã từ chối hồ sơ Chủ sân 1'), findsOneWidget);
  });

  testWidgets('lỗi 409 khi duyệt hiện SnackBar và giữ nút thao tác', (
    tester,
  ) async {
    final repository = FakeOwnerRepository([owner(1)])
      ..decisionFailure = const ServerFailure(
        'Hồ sơ đã được xử lý. Vui lòng tải lại danh sách.',
        statusCode: 409,
      );
    await pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Hồ sơ đã được xử lý. Vui lòng tải lại danh sách.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Duyệt'), findsOneWidget);
  });

  testWidgets('chi tiết hiển thị thông tin và mở ảnh giấy phép có zoom', (
    tester,
  ) async {
    final repository = FakeOwnerRepository([
      owner(
        1,
        documents: [
          OwnerDocument(
            id: 11,
            url: Uri.parse('https://cdn.fcourt.vn/legal.jpg'),
            type: OwnerDocumentType.legal,
          ),
        ],
      ),
    ]);
    await pumpDetail(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('owner1@fcourt.vn'), findsOneWidget);
    expect(find.text('0900000001'), findsOneWidget);
    expect(find.text('Giấy phép kinh doanh / CCCD'), findsOneWidget);
    expect(find.text('Số CCCD'), findsOneWidget);

    await tester.ensureVisible(find.text('image:/legal.jpg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('image:/legal.jpg'));
    await tester.pumpAndSettle();

    expect(find.byType(ZoomableImagePage), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
