import 'dart:async';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/vouchers/domain/voucher.dart';
import 'package:fcourt/features/vouchers/domain/voucher_draft.dart';
import 'package:fcourt/features/vouchers/domain/voucher_repository.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../admin_facility/fixtures.dart';
import '../admin_facility/mocks.dart';
import 'repository_test.dart' show voucher;

class PendingVouchers implements VoucherRepository {
  final calls = <({int branch, int page, Completer<VoucherPage> result})>[];
  final changes = <Completer<Voucher>>[];
  @override
  Future<VoucherPage> list(int branchId, {int page = 0}) {
    final result = Completer<VoucherPage>();
    calls.add((branch: branchId, page: page, result: result));
    return result.future;
  }

  @override
  Future<Voucher> setEnabled(int id, int branchId, bool enabled) {
    final result = Completer<Voucher>();
    changes.add(result);
    return result.future;
  }

  @override
  Future<Voucher> get(int id, int branchId) => throw UnimplementedError();
  @override
  Future<Voucher> save(VoucherDraft draft, {int? id, int usedCount = 0}) =>
      throw UnimplementedError();
}

(VoucherCubit, PendingVouchers, MockBranchRepository) setup() {
  final branches = MockBranchRepository();
  when(() => branches.getBranches())
      .thenAnswer((_) async => [sampleBranch(), sampleBranch(id: 2)]);
  final repository = PendingVouchers();
  return (VoucherCubit(repository, branches), repository, branches);
}

Future<void> initialize(
  WidgetTester tester,
  VoucherCubit cubit,
  PendingVouchers repository,
) async {
  final initial = cubit.initialize();
  await tester.pump();
  repository.calls.last.result.complete(VoucherPage([voucher()], 0, 41));
  await initial;
}

void main() {
  testWidgets(
    'activation prevents duplicate taps and ignores completion for old branch',
    (tester) async {
      final (cubit, repository, _) = setup();
      await initialize(tester, cubit, repository);
      final change = cubit.setEnabled(voucher(), false);
      await cubit.setEnabled(voucher(), false);
      expect(repository.changes.length, 1);
      expect(cubit.state.busyIds, {1});
      final switchBranch = cubit.selectBranch(2);
      repository.calls.last.result.complete(
        VoucherPage([voucher(id: 2, branchId: 2)], 0, 1),
      );
      await switchBranch;
      repository.changes.single.complete(voucher());
      await change;
      expect(cubit.state.items.single.id, 2);
      expect(cubit.state.busyIds, isEmpty);
      await cubit.close();
    },
  );
  testWidgets(
    'pagination errors retain rows and retries deduplicate identities',
    (tester) async {
      final (cubit, repository, _) = setup();
      await initialize(tester, cubit, repository);
      final more = cubit.loadMore();
      await cubit.loadMore();
      expect(repository.calls.length, 2);
      repository.calls.last.result.completeError(const NetworkFailure());
      await more;
      expect(cubit.state.items.single.id, 1);
      expect(cubit.state.error, isNotNull);
      final retry = cubit.loadMore();
      repository.calls.last.result.complete(
        VoucherPage([voucher(), voucher(id: 2)], 1, 22),
      );
      await retry;
      expect(cubit.state.items.map((row) => row.id), [1, 2]);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    },
  );
  testWidgets('old page cannot replace vouchers after switching owned branch', (
    tester,
  ) async {
    final (cubit, repository, _) = setup();
    await initialize(tester, cubit, repository);
    final more = cubit.loadMore();
    final old = repository.calls.last;
    final switchBranch = cubit.selectBranch(2);
    repository.calls.last.result.complete(
      VoucherPage([voucher(id: 2, branchId: 2)], 0, 1),
    );
    await switchBranch;
    old.result.complete(VoucherPage([voucher(id: 99)], 1, 41));
    await more;
    expect(cubit.state.branchId, 2);
    expect(cubit.state.items.single.id, 2);
    await cubit.close();
  });
}
