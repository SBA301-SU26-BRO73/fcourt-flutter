import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/admin_branch_images_cubit.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/admin_branch_images_screen.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/branch_gallery_section.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/widgets/branch_image_carousel.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/widgets/branch_image_lightbox.dart';
import 'package:fcourt/src/features/branch_gallery/presentation/widgets/branch_image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gallery_helpers.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

const _placeholder = Text('Ảnh sân chưa cập nhật');

void main() {
  final urls = [for (var i = 1; i <= 3; i++) 'https://cdn.example.com/$i.png'];

  setUp(
    () =>
        BranchImageView.debugBuilder = (url, fit) =>
            SizedBox.expand(key: ValueKey(url)),
  );
  tearDown(() => BranchImageView.debugBuilder = null);

  testWidgets(
    'image view shows a loading indicator while the photo downloads',
    (tester) async {
      BranchImageView.debugBuilder = null;
      await _pump(
        tester,
        const SizedBox(
          height: 100,
          child: BranchImageView(url: 'https://cdn.example.com/x.png'),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  group('carousel and lightbox', () {
    testWidgets(
      'swipes between photos and tapping opens a full-screen viewer at that photo',
      (tester) async {
        await _pump(tester, BranchImageCarousel(urls: urls));
        expect(find.text('1/3'), findsOneWidget);

        await tester.drag(
          find.byKey(const Key('carousel-pages')),
          const Offset(-600, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('2/3'), findsOneWidget);

        await tester.tap(
          find.byType(BranchImageView).first,
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(find.byType(BranchImageLightbox), findsOneWidget);
        expect(find.text('2/3'), findsOneWidget);
      },
    );

    testWidgets(
      'closing the viewer returns the carousel to the last viewed photo',
      (tester) async {
        await _pump(tester, BranchImageCarousel(urls: urls));
        await tester.tap(
          find.byType(BranchImageView).first,
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byKey(const Key('lightbox-pages')),
          const Offset(-600, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('2/3'), findsOneWidget);

        await tester.tap(find.byTooltip('Đóng'));
        await tester.pumpAndSettle();
        expect(find.byType(BranchImageLightbox), findsNothing);
        expect(find.text('2/3'), findsOneWidget);
      },
    );

    testWidgets('a single photo shows no page dots but is still openable', (
      tester,
    ) async {
      await _pump(tester, BranchImageCarousel(urls: urls.take(1).toList()));
      expect(find.byType(AnimatedContainer), findsNothing);
      await tester.tap(find.byType(BranchImageView).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(BranchImageLightbox), findsOneWidget);
    });
  });

  group('customer gallery section', () {
    testWidgets('shows the carousel when the branch has photos', (
      tester,
    ) async {
      await _pump(
        tester,
        BranchGallerySection(
          repository: FakeBranchImages([image(1), image(2)]),
          branchId: 3,
          placeholder: _placeholder,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BranchImageCarousel), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Ảnh sân chưa cập nhật'), findsNothing);
    });

    testWidgets('falls back to the placeholder when there are no photos', (
      tester,
    ) async {
      await _pump(
        tester,
        BranchGallerySection(
          repository: FakeBranchImages(),
          branchId: 3,
          placeholder: _placeholder,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ảnh sân chưa cập nhật'), findsOneWidget);
      expect(find.byType(BranchImageCarousel), findsNothing);
    });

    testWidgets(
      'load failure keeps the placeholder and offers a retry that recovers',
      (tester) async {
        final repo = FakeBranchImages([image(1)])
          ..failure = const NetworkFailure();
        await _pump(
          tester,
          BranchGallerySection(
            repository: repo,
            branchId: 3,
            placeholder: _placeholder,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(const NetworkFailure().message), findsOneWidget);
        expect(find.text('Ảnh sân chưa cập nhật'), findsOneWidget);

        repo.failure = null;
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        expect(find.byType(BranchImageCarousel), findsOneWidget);
      },
    );
  });

  group('admin images screen', () {
    Future<(FakeBranchImages, FakePicker)> open(
      WidgetTester tester, [
      List<int> ids = const [1, 2],
    ]) async {
      final repo = FakeBranchImages([for (final id in ids) image(id)]);
      final picker = FakePicker();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => AdminBranchImagesCubit(
              repository: repo,
              picker: picker,
              branchId: 3,
            )..load(),
            child: const AdminBranchImagesScreen(branchName: 'Sân A'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (repo, picker);
    }

    testWidgets('adding photos shows them right away with a confirmation', (
      tester,
    ) async {
      final (repo, picker) = await open(tester);
      expect(find.text('2/10 ảnh'), findsOneWidget);
      picker.next = [picked('a.jpg'), picked('b.jpg')];
      await tester.tap(find.byKey(const Key('add-images')));
      await tester.pumpAndSettle();
      expect(repo.uploaded.single, ['a.jpg', 'b.jpg']);
      expect(find.text('4/10 ảnh'), findsOneWidget);
      expect(find.text('Đã thêm 2 ảnh.'), findsOneWidget);
    });

    testWidgets('deleting asks for confirmation, then removes the tile', (
      tester,
    ) async {
      final (repo, _) = await open(tester);
      await tester.tap(find.byKey(const Key('delete-image-1')));
      await tester.pumpAndSettle();
      expect(find.text('Xóa ảnh?'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.deleted, isEmpty);

      await tester.tap(find.byKey(const Key('delete-image-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(repo.deleted, [1]);
      expect(find.byKey(const Key('delete-image-1')), findsNothing);
      expect(find.byKey(const Key('delete-image-2')), findsOneWidget);
    });

    testWidgets(
      'empty gallery explains how to add photos; full gallery disables the button',
      (tester) async {
        await open(tester, const []);
        expect(find.textContaining('chưa có ảnh'), findsOneWidget);
      },
    );

    testWidgets('full gallery disables adding', (tester) async {
      await open(tester, [for (var i = 1; i <= 10; i++) i]);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('add-images')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Đã đủ 10 ảnh'), findsOneWidget);
    });

    testWidgets('tapping a tile opens the same full-screen viewer', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byType(BranchImageView).first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(BranchImageLightbox), findsOneWidget);
    });
  });
}
