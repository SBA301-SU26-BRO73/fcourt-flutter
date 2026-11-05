import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:fcourt/features/reviews/presentation/rating_bottom_sheet.dart';
import 'package:fcourt/features/reviews/presentation/review_list_widget.dart';
import 'package:fcourt/features/booking_history/data/booking_repository_impl.dart';
import 'package:fcourt/features/booking_history/presentation/booking_detail_screen.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';

import '../../helpers/fake_adapter.dart';
import '../booking_history/booking_history_test.dart' show raw;
import 'review_fakes.dart';

void main() {
  testWidgets(
    'stars require selection, animate emotion and submit once with thanks',
    (tester) async {
      final repo = Reviews();
      addTearDown(repo.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final result = await showRatingBottomSheet(
                    context,
                    repository: repo,
                    bookingId: 10,
                  );
                  if (context.mounted && result != null)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cảm ơn bạn đã đánh giá sân!'),
                      ),
                    );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Gửi đánh giá'));
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      expect(find.text('Vui lòng chọn số sao trước khi gửi.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('5 sao · Tuyệt vời'));
      await tester.tap(find.byTooltip('5 sao · Tuyệt vời'));
      await tester.pumpAndSettle();
      expect(find.text('Tuyệt vời'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Sân đẹp');
      await tester.ensureVisible(find.text('Gửi đánh giá'));
      await tester.tap(find.text('Gửi đánh giá'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(find.text('Cảm ơn bạn đã đánh giá sân!'), findsOneWidget);
    },
  );
  testWidgets(
    'photo preview cannot be submitted without agreed upload endpoint',
    (tester) async {
      final repo = Reviews();
      addTearDown(repo.events.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showRatingBottomSheet(
                  context,
                  repository: repo,
                  bookingId: 10,
                  picker: Photos(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('4 sao · Tốt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chọn ảnh'));
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('1/5 ảnh'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi đánh giá'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byTooltip('Bỏ ảnh 1'));
      await tester.tap(find.byTooltip('Bỏ ảnh 1'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi đánh giá'),
            )
            .onPressed,
        isNotNull,
      );
      expect(repo.writes, 0);
    },
  );
  testWidgets('branch tab renders backend summary and owner reply', (
    tester,
  ) async {
    final repo = Reviews();
    addTearDown(repo.events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BranchDetailScreen(
          branchId: 7,
          reviews: repo,
          branch: const Branch(
            id: 7,
            name: 'Sân A',
            address: 'A',
            city: 'HCM',
            courtCount: 1,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(Tab, 'Đánh giá'));
    await tester.pumpAndSettle();
    expect(find.text('5.00/5 · 1 đánh giá'), findsOneWidget);
    expect(find.text('Khách hàng #3'), findsOneWidget);
    expect(find.text('Phản hồi của chủ sân'), findsOneWidget);
    expect(find.text('Cảm ơn bạn'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
  testWidgets('list refreshes immediately after a review change event', (
    tester,
  ) async {
    final repo = Reviews();
    addTearDown(repo.events.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReviewListWidget(repository: repo, branchId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.calls.length, 1);
    repo.events.add(7);
    await tester.pumpAndSettle();
    expect(repo.calls.length, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('only COMPLETED booking details expose review action', (
    tester,
  ) async {
    for (final status in [
      'CONFIRMED',
      'CHECKED_IN',
      'CANCELLED',
      'COMPLETED',
    ]) {
      final repo = BookingRepositoryImpl(
        Dio()
          ..httpClientAdapter = FakeAdapter(
            (_) => jsonResponse(200, {...raw(), 'status': status}),
          ),
      );
      int? id;
      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetailScreen(
            key: ValueKey(status),
            repository: repo,
            id: 1,
            onReview: (value) async {
              id = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Đánh giá sân'),
        status == 'COMPLETED' ? findsOneWidget : findsNothing,
      );
      if (status == 'COMPLETED') {
        await tester.tap(find.text('Đánh giá sân'));
        await tester.pumpAndSettle();
        expect(id, 1);
      }
    }
  });
}
