import 'dart:async';

import 'package:fcourt/core/error/failure.dart';
import 'package:fcourt/features/vouchers/domain/voucher.dart';
import 'package:fcourt/features/vouchers/domain/voucher_draft.dart';
import 'package:fcourt/features/vouchers/domain/voucher_repository.dart';
import 'package:fcourt/features/vouchers/presentation/voucher_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'repository_test.dart' show voucher;

class EditorRepository implements VoucherRepository {
  final drafts = <VoucherDraft>[];
  Failure? failure;
  Completer<Voucher>? pending;
  @override
  Future<VoucherPage> list(int branchId, {int page = 0}) async =>
      VoucherPage([voucher()], 0, 1);
  @override
  Future<Voucher> get(int id, int branchId) async => voucher();
  @override
  Future<Voucher> save(VoucherDraft draft, {int? id, int usedCount = 0}) async {
    drafts.add(draft);
    if (failure != null) throw failure!;
    return pending == null ? voucher() : pending!.future;
  }

  @override
  Future<Voucher> setEnabled(int id, int branchId, bool enabled) async =>
      voucher();
}

Future<void> openEditor(
  WidgetTester tester,
  EditorRepository repository, {
  int? id,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<Voucher>(
              context: context,
              isScrollControlled: true,
              isDismissible: false,
              enableDrag: false,
              builder: (_) =>
                  VoucherEditor(repository: repository, branchId: 1, id: id),
            ),
            child: const Text('Mở form'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Mở form'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

void main() {
  testWidgets(
    'negative amounts block submit and duplicate errors retain form; saving blocks repeated taps',
    (tester) async {
      final repository = EditorRepository();
      await openEditor(tester, repository);
      await tester.enterText(field('Mã voucher'), 'NEW_CODE');
      await tester.enterText(field('Giá trị giảm (%)'), '-1');
      await tester.tap(find.text('Lưu voucher'));
      await tester.pumpAndSettle();
      expect(repository.drafts, isEmpty);
      expect(find.textContaining('Nhập số không âm'), findsOneWidget);
      await tester.enterText(field('Giá trị giảm (%)'), '12.5');
      repository.failure = const ServerFailure(
        'Mã voucher đã tồn tại',
        statusCode: 409,
      );
      await tester.tap(find.text('Lưu voucher'));
      await tester.pumpAndSettle();
      expect(find.text('Mã voucher đã tồn tại'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Mã voucher')).controller!.text,
        'NEW_CODE',
      );
      repository.failure = null;
      repository.pending = Completer<Voucher>();
      await tester.tap(find.text('Lưu voucher'));
      await tester.pump();
      expect(repository.drafts.length, 2);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<IconButton>(find.byTooltip('Đóng form')).onPressed,
        isNull,
      );
      repository.pending!.complete(voucher());
      await tester.pumpAndSettle();
      expect(find.byType(VoucherEditor), findsNothing);
    },
  );
}
