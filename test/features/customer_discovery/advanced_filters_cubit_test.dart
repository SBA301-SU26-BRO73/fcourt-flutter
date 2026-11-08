import 'dart:async';

import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/discovery_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'discovery_cubit_test.dart' show result;

class FilterRequest {
  FilterRequest(this.filters, this.sport, this.query, this.page);
  final DiscoveryFilters filters;
  final DiscoverySport? sport;
  final String query;
  final int page;
  final result = Completer<BranchPage>();
}

class FilterRepository implements DiscoveryRepository {
  final calls = <FilterRequest>[];
  @override
  Future<BranchPage> search({
    String query = '',
    DiscoverySport? sport,
    DiscoveryFilters filters = const DiscoveryFilters(),
    int page = 0,
  }) {
    final call = FilterRequest(filters, sport, query, page);
    calls.add(call);
    return call.result.future;
  }
}

void main() {
  testWidgets(
    'filters survive search, sport, refresh and pagination; reset preserves query',
    (tester) async {
      final repository = FilterRepository();
      final cubit = DiscoveryCubit(repository, query: 'Sân A');
      const filters = DiscoveryFilters(minPrice: '100000', district: 'Thủ Đức');
      cubit.updateFilters(filters);
      await tester.pump(const Duration(milliseconds: 300));
      repository.calls.last.result.complete(result(0, [1]));
      await tester.pump();
      final more = cubit.loadMore();
      final stalePage = repository.calls.last;
      expect(stalePage.page, 1);
      expect(stalePage.filters, same(filters));
      cubit.filter(DiscoverySport.badminton);
      expect(repository.calls.last.filters, same(filters));
      repository.calls.last.result.complete(result(0, [2]));
      await tester.pump();
      stalePage.result.complete(result(1, [3]));
      await more;
      expect(cubit.state.branches.single.id, 2);
      final refresh = cubit.refresh();
      expect(repository.calls.last.filters, same(filters));
      repository.calls.last.result.complete(result(0, [2]));
      await refresh;
      cubit.search('Sân B');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.calls.last.filters, same(filters));
      repository.calls.last.result.complete(result(0, [2]));
      await tester.pump();
      cubit.resetFilters();
      expect(repository.calls.last.query, 'Sân B');
      expect(repository.calls.last.sport, isNull);
      expect(repository.calls.last.filters.count, 0);
      expect(repository.calls.last.page, 0);
      repository.calls.last.result.complete(result(0, [1]));
      await tester.pump();
      await cubit.close();
    },
  );
  testWidgets(
    'filters update immediately, debounce calls and ignore old responses',
    (tester) async {
      final repository = FilterRepository();
      final cubit = DiscoveryCubit(repository);
      final first = cubit.refresh();
      cubit.updateFilters(const DiscoveryFilters(city: 'HCM'));
      repository.calls.first.result.complete(result(0, [1]));
      await first;
      expect(cubit.state.branches, isEmpty);
      await tester.pump(const Duration(milliseconds: 150));
      cubit.updateFilters(
        const DiscoveryFilters(city: 'HCM', hasAvailableSlotsToday: true),
      );
      expect(cubit.state.filters.hasAvailableSlotsToday, isTrue);
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.calls.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.calls.last.filters.city, 'HCM');
      expect(repository.calls.last.filters.hasAvailableSlotsToday, isTrue);
      repository.calls.last.result.complete(result(0, [2]));
      await tester.pump();
      expect(cubit.state.branches.single.id, 2);
      expect(cubit.state.total, 3);
      await cubit.close();
    },
  );

  testWidgets(
    'invalid draft cancels an earlier valid filter debounce and keeps last valid filters',
    (tester) async {
      final repository = FilterRepository();
      final cubit = DiscoveryCubit(repository);
      const valid = DiscoveryFilters(city: 'HCM');

      cubit.updateFilters(valid);
      await tester.pump(const Duration(milliseconds: 150));
      cubit.updateFilters(const DiscoveryFilters(minPrice: 'not-a-price'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.calls, isEmpty);
      expect(cubit.state.filters, same(valid));
      await cubit.close();
    },
  );
}
