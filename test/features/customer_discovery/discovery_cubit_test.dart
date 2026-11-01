import 'dart:async';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/discovery_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingSearch {
  PendingSearch(this.query, this.sport, this.page);
  final String query;
  final DiscoverySport? sport;
  final int page;
  final result = Completer<BranchPage>();
}

class PendingRepository implements DiscoveryRepository {
  final calls = <PendingSearch>[];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    int page = 0,
  }) {
    final call = PendingSearch(query, sport, page);
    calls.add(call);
    return call.result.future;
  }
}

Branch branch(int id) => Branch(
  id: id,
  name: 'Branch $id',
  address: 'A',
  city: 'HCM',
  courtCount: 1,
);
BranchPage result(int page, List<int> ids) => BranchPage(
  branches: ids.map(branch).toList(),
  page: page,
  totalPages: 2,
  totalElements: 3,
);

void main() {
  testWidgets('closing cancels debounce and safely ignores a pending request', (
    tester,
  ) async {
    final repository = PendingRepository();
    final cubit = DiscoveryCubit(repository);
    final pending = cubit.refresh();
    cubit.search('cancelled');
    await cubit.close();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repository.calls.length, 1);
    repository.calls.single.result.complete(result(0, [1]));
    await pending;
    expect(cubit.state.branches, isEmpty);
  });

  testWidgets('debounces typing and ignores old results even during debounce', (
    tester,
  ) async {
    final repository = PendingRepository();
    final cubit = DiscoveryCubit(repository);
    final first = cubit.refresh();
    cubit.search('a');
    await tester.pump(const Duration(milliseconds: 150));
    cubit.search('ab');
    repository.calls.first.result.complete(result(0, [1]));
    await first;
    expect(cubit.state.branches, isEmpty);
    await tester.pump(const Duration(milliseconds: 299));
    expect(repository.calls.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.calls.last.query, 'ab');
    repository.calls.last.result.complete(result(0, [2]));
    await tester.pump();
    expect(cubit.state.branches.single.id, 2);
    await cubit.close();
  });

  test(
    'filter resets pages and late pagination cannot overwrite new results',
    () async {
      final repository = PendingRepository();
      final cubit = DiscoveryCubit(repository);
      final first = cubit.refresh();
      repository.calls.last.result.complete(result(0, [1]));
      await first;
      final more = cubit.loadMore();
      expect(repository.calls.last.page, 1);
      final old = repository.calls.last;
      cubit.filter(DiscoverySport.tennis);
      expect(repository.calls.last.sport, DiscoverySport.tennis);
      expect(repository.calls.last.page, 0);
      repository.calls.last.result.complete(result(0, [3]));
      await Future<void>.delayed(Duration.zero);
      old.result.complete(result(1, [2]));
      await more;
      expect(cubit.state.branches.single.id, 3);
      await cubit.close();
    },
  );

  test(
    'pagination deduplicates IDs and retains results on retryable failure',
    () async {
      final repository = PendingRepository();
      final cubit = DiscoveryCubit(repository);
      final first = cubit.refresh();
      repository.calls.last.result.complete(result(0, [1, 2]));
      await first;
      final failed = cubit.loadMore();
      await cubit.loadMore();
      expect(repository.calls.length, 2);
      repository.calls.last.result.completeError(const NetworkFailure());
      await failed;
      expect(cubit.state.branches.length, 2);
      expect(cubit.state.error, isNotNull);
      final retry = cubit.loadMore();
      repository.calls.last.result.complete(result(1, [2, 3]));
      await retry;
      expect(cubit.state.branches.map((b) => b.id), [1, 2, 3]);
      expect(cubit.state.hasNext, isFalse);
      await cubit.close();
    },
  );
}
