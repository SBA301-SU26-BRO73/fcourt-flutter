import 'package:fcourt/src/features/branch_gallery/presentation/widgets/branch_image_carousel.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/widgets/branch_image_view.dart';
import 'package:fcourt/src/features/customer_discovery/domain/discovery_repository.dart';
import 'package:fcourt/src/features/customer_discovery/presentation/screens/branch_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_helpers.dart';

const _branch = Branch(
  id: 3,
  name: 'Sân A',
  address: '1 Đường A',
  city: 'HCM',
  courtCount: 2,
);

Future<void> _open(WidgetTester tester, FakeBranchImages? repo) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: BranchDetailScreen(
        branchId: 3,
        branch: _branch,
        galleryRepository: repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () =>
        BranchImageView.debugBuilder = (url, fit) =>
            SizedBox.expand(key: ValueKey(url)),
  );
  tearDown(() => BranchImageView.debugBuilder = null);

  testWidgets(
    'customer detail shows the photo carousel when the branch has photos',
    (tester) async {
      await _open(tester, FakeBranchImages([image(1), image(2)]));
      expect(find.byType(BranchImageCarousel), findsOneWidget);
      expect(find.text('Ảnh sân chưa cập nhật'), findsNothing);
      expect(find.text('Sân A'), findsOneWidget);
    },
  );

  testWidgets(
    'customer detail keeps the default artwork when there are no photos',
    (tester) async {
      await _open(tester, FakeBranchImages());
      expect(find.byType(BranchImageCarousel), findsNothing);
      expect(find.text('Ảnh sân chưa cập nhật'), findsOneWidget);
    },
  );

  testWidgets('without a gallery source the detail screen is unchanged', (
    tester,
  ) async {
    await _open(tester, null);
    expect(find.text('Ảnh sân chưa cập nhật'), findsOneWidget);
  });
}
