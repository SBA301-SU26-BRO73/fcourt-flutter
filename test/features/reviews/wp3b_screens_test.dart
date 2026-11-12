import 'dart:async';

import 'package:fcourt/features/reviews/domain/review.dart';
import 'package:fcourt/features/reviews/presentation/rating_bottom_sheet.dart';
import 'package:fcourt/features/reviews/presentation/review_list_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

class _Reviews implements ReviewRepository {
  final _changes = StreamController<int>.broadcast();
  @override
  Stream<int> get changes => _changes.stream;
  @override
  Future<ReviewPage> list(int branchId, {int page = 0}) async => ReviewPage(
    items: [
      CourtReview(
        id: 1,
        branchId: branchId,
        courtId: 2,
        reviewerName: 'Nguyễn Hoàng An',
        rating: 5,
        createdAt: DateTime.utc(2026, 11, 5, 11, 30),
        comment: 'Sân sạch, đèn sáng đều, chủ sân nhiệt tình. Sẽ quay lại.',
        adminReply: 'Cảm ơn bạn đã ủng hộ, hẹn gặp lại bạn!',
      ),
      CourtReview(
        id: 2,
        branchId: branchId,
        courtId: 3,
        reviewerName: 'Trần Minh Khoa',
        rating: 4,
        createdAt: DateTime.utc(2026, 11, 2, 14),
        comment: 'Mặt sân tốt, giờ cao điểm hơi đông.',
      ),
      CourtReview(
        id: 3,
        branchId: branchId,
        courtId: 3,
        rating: 3,
        createdAt: DateTime.utc(2026, 10, 28, 3),
      ),
    ],
    page: 0,
    total: 12,
    average: 4.5,
    starCounts: const {1: 0, 2: 1, 3: 2, 4: 3, 5: 6},
  );
  @override
  Future<CourtReview> create(
    int bookingId,
    int rating,
    String comment,
    List<String> imageUrls,
  ) async => throw UnimplementedError();
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('branch reviews tab matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        back: true,
        Scaffold(
          appBar: AppBar(title: const Text('Sân Cầu Lông Ba Đình')),
          body: ReviewListWidget(repository: _Reviews(), branchId: 7),
        ),
      );
      await wp3bShot(tester, key, 'reviews-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('4.50/5 · 12 đánh giá'), findsOneWidget);
      expect(find.text('Phản hồi của chủ sân'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('write review sheet matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final repo = _Reviews();
      final key = await wp3bPump(
        tester,
        b,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showRatingBottomSheet(
                  context,
                  repository: repo,
                  bookingId: 1,
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
      await wp3bShot(tester, key, 'review-sheet-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Gửi đánh giá'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
