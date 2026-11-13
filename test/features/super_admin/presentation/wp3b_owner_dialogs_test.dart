import 'package:fcourt/features/super_admin/domain/entities/court_owner.dart';
import 'package:fcourt/features/super_admin/presentation/widgets/owner_decision_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/wp3b_shots.dart';

const _owner = CourtOwner(
  id: 1,
  email: 'chu.san@fcourt.vn',
  fullName: 'Nguyễn Văn An',
  status: OwnerStatus.pendingApproval,
);

void main() {
  for (final b in Brightness.values) {
    for (final approve in [true, false]) {
      final name = approve ? 'owner-approve' : 'owner-reject';
      testWidgets('$name dialog matches the WP3b look (${b.name})', (
        tester,
      ) async {
        await pumpShot(
          tester,
          b,
          const Scaffold(body: SizedBox.expand()),
          name: name,
          prepare: (tester) async {
            final context = tester.element(find.byType(Scaffold));
            if (approve) {
              showApproveOwnerDialog(context, _owner);
            } else {
              showRejectOwnerDialog(context, _owner);
            }
            await tester.pump(const Duration(milliseconds: 600));
          },
        );
        expect(find.byType(AlertDialog), findsOneWidget);
      });
    }
  }
}
