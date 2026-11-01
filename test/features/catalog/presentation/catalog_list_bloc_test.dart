import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/catalog/domain/entities/court_type.dart';
import 'package:fcourt/features/catalog/domain/entities/page_result.dart';
import 'package:fcourt/features/catalog/presentation/bloc/catalog_list_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

typedef _Loader = Future<PageResult<CourtType>> Function(int page);

CatalogListBloc<CourtType> _bloc({
  required _Loader load,
  Future<void> Function(int id)? delete,
}) =>
    CatalogListBloc<CourtType>(
      load: load,
      delete: delete ?? (_) async {},
      idOf: (courtType) => courtType.id,
      deletedMessage: 'Đã xóa loại sân',
    );

CatalogListState<CourtType> _ready(
  List<CourtType> items, {
  int page = 0,
  bool hasMore = false,
}) =>
    CatalogListState<CourtType>(
      status: CatalogListStatus.ready,
      items: items,
      page: page,
      hasMore: hasMore,
    );

void main() {
  group('CatalogRefreshed', () {
    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'lần đầu: loading rồi ready kèm danh sách và cờ còn trang',
      build: () => _bloc(load: (_) async => pageOf([badminton, football], totalPages: 2)),
      act: (bloc) => bloc.add(const CatalogRefreshed()),
      expect: () => [
        CatalogListState<CourtType>(),
        _ready([badminton, football], hasMore: true),
      ],
      verify: (bloc) => expect(bloc.state.status, CatalogListStatus.ready),
    );

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'lỗi khi chưa có dữ liệu thì failure kèm lý do để hiện nút thử lại',
      build: () => _bloc(load: (_) async => throw const NetworkFailure()),
      act: (bloc) => bloc.add(const CatalogRefreshed()),
      expect: () => [
        CatalogListState<CourtType>(),
        CatalogListState<CourtType>(
          status: CatalogListStatus.failure,
          message: 'Không kết nối được máy chủ',
        ),
      ],
    );

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'làm mới khi đã có dữ liệu: giữ danh sách cũ, đánh dấu refreshing rồi thay bằng dữ liệu mới',
      build: () => _bloc(load: (_) async => pageOf([football])),
      seed: () => _ready([badminton]),
      act: (bloc) => bloc.add(const CatalogRefreshed()),
      expect: () => [
        _ready([badminton]).copyWith(refreshing: true),
        _ready([football]),
      ],
    );

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'làm mới lỗi khi đã có dữ liệu: giữ danh sách và báo lỗi bằng thông báo, không đổi sang failure',
      build: () => _bloc(load: (_) async => throw const NetworkFailure()),
      seed: () => _ready([badminton]),
      act: (bloc) => bloc.add(const CatalogRefreshed()),
      expect: () => [
        _ready([badminton]).copyWith(refreshing: true),
        _ready([badminton]).copyWith(
          refreshing: false,
          notice: const CatalogNotice('Không kết nối được máy chủ', isError: true, sequence: 1),
        ),
      ],
    );
  });

  group('CatalogMoreRequested', () {
    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'tải trang kế tiếp và nối vào danh sách',
      build: () => _bloc(load: (page) async => pageOf([football], page: page, totalPages: 2)),
      seed: () => _ready([badminton], hasMore: true),
      act: (bloc) => bloc.add(const CatalogMoreRequested()),
      expect: () => [
        _ready([badminton], hasMore: true).copyWith(loadingMore: true),
        _ready([badminton, football], page: 1),
      ],
    );

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'hết trang thì không gọi BE',
      build: () => _bloc(load: (_) async => throw StateError('không được gọi')),
      seed: () => _ready([badminton]),
      act: (bloc) => bloc.add(const CatalogMoreRequested()),
      expect: () => <CatalogListState<CourtType>>[],
    );

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'tải thêm lỗi thì giữ danh sách, tắt vòng chờ và báo lỗi',
      build: () => _bloc(load: (_) async => throw const NetworkFailure()),
      seed: () => _ready([badminton], hasMore: true),
      act: (bloc) => bloc.add(const CatalogMoreRequested()),
      expect: () => [
        _ready([badminton], hasMore: true).copyWith(loadingMore: true),
        _ready([badminton], hasMore: true).copyWith(
          notice: const CatalogNotice('Không kết nối được máy chủ', isError: true, sequence: 1),
        ),
      ],
    );

    test('bấm tải thêm hai lần liên tiếp chỉ gọi BE một lần', () async {
      var calls = 0;
      final completer = Completer<PageResult<CourtType>>();
      final bloc = _bloc(load: (_) {
        calls++;
        return completer.future;
      })
        ..emit(_ready([badminton], hasMore: true));

      bloc
        ..add(const CatalogMoreRequested())
        ..add(const CatalogMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      completer.complete(pageOf([football], page: 1, totalPages: 2));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(calls, 1);
      await bloc.close();
    });

    test('làm mới khi đang tải thêm thì bỏ trang cũ về muộn, không nhân đôi', () async {
      final more = Completer<PageResult<CourtType>>();
      final bloc = _bloc(
        load: (page) async => page == 0
            ? pageOf([badminton], totalPages: 2)
            : more.future,
      )..emit(_ready([badminton], hasMore: true));

      bloc.add(const CatalogMoreRequested());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const CatalogRefreshed());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      more.complete(pageOf([football], page: 1, totalPages: 2));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.state.items, [badminton]);
      expect(bloc.state.page, 0);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.loadingMore, isFalse);
      await bloc.close();
    });
  });

  group('CatalogItemDeleted', () {
    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'xóa thành công thì bỏ mục khỏi danh sách và báo đã xóa',
      build: () => _bloc(load: (_) async => pageOf([])),
      seed: () => _ready([badminton, football]),
      act: (bloc) => bloc.add(const CatalogItemDeleted(1)),
      expect: () => [
        _ready([badminton, football]).copyWith(deletingId: () => 1),
        _ready([football]).copyWith(
          notice: const CatalogNotice('Đã xóa loại sân', isError: false, sequence: 1),
        ),
      ],
    );

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'xóa lỗi thì giữ nguyên danh sách và báo lỗi của BE',
      build: () => _bloc(
        load: (_) async => pageOf([]),
        delete: (_) async => throw const ServerFailure('Court type not found', statusCode: 404),
      ),
      seed: () => _ready([badminton]),
      act: (bloc) => bloc.add(const CatalogItemDeleted(1)),
      expect: () => [
        _ready([badminton]).copyWith(deletingId: () => 1),
        _ready([badminton]).copyWith(
          notice: const CatalogNotice('Court type not found', isError: true, sequence: 1),
        ),
      ],
    );

    test('đang xóa một mục thì bỏ qua yêu cầu xóa mục khác', () async {
      final deleted = <int>[];
      final completer = Completer<void>();
      final bloc = _bloc(
        load: (_) async => pageOf([]),
        delete: (id) {
          deleted.add(id);
          return completer.future;
        },
      )..emit(_ready([badminton, football]));

      bloc
        ..add(const CatalogItemDeleted(1))
        ..add(const CatalogItemDeleted(2));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      completer.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(deleted, [1]);
      await bloc.close();
    });

    blocTest<CatalogListBloc<CourtType>, CatalogListState<CourtType>>(
      'hai lần xóa thành công liên tiếp tạo hai thông báo khác nhau để giao diện hiện cả hai',
      build: () => _bloc(load: (_) async => pageOf([])),
      seed: () => _ready([badminton, football]),
      act: (bloc) async {
        bloc.add(const CatalogItemDeleted(1));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const CatalogItemDeleted(2));
      },
      verify: (bloc) {
        expect(bloc.state.items, isEmpty);
        expect(bloc.state.notice?.sequence, 2);
      },
    );
  });
}
