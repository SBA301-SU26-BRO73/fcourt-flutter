import 'package:fcourt/app/widgets/wp3b_widgets.dart';
import 'package:fcourt/features/maps/domain/branch_location.dart';
import 'package:fcourt/features/maps/presentation/branch_map_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/wp3b_shots.dart';

class _Maps implements BranchMapPlatform {
  @override
  Future<BranchMapAvailability> availability() async =>
      BranchMapAvailability.available;
  @override
  Future<bool> directions(BranchLocation location) async => true;
  @override
  Future<bool> openStreetMap(BranchLocation location) async => true;
  @override
  Future<bool> attribution() async => true;
}

/// Stand-in for the native map (a real one cannot render in a widget test).
class _FakeMap extends StatelessWidget {
  const _FakeMap();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFE8EEF4),
    child: Center(child: Icon(Icons.location_on, size: 40)),
  );
}

void main() {
  final location = BranchLocation.parse(21.0367, 105.8342)!;
  for (final b in Brightness.values) {
    testWidgets('branch map sheet matches the mock-up (${b.name})', (
      tester,
    ) async {
      if (wp3bShotDir != null) await wp3bLoadFonts();
      final key = await wp3bPump(
        tester,
        b,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) => Wp3bSheet(
                    title: 'Vị trí chi nhánh',
                    subtitle: 'Sân Cầu Lông Ba Đình',
                    child: BranchMapCard(
                      location: location,
                      name: 'Sân Cầu Lông Ba Đình',
                      platform: _Maps(),
                      nativeBuilder: (_, _, ready) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => ready(),
                        );
                        return const _FakeMap();
                      },
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await wp3bShot(tester, key, 'map-${b.name}');
      expect(tester.takeException(), isNull);
      expect(find.text('Chỉ đường đến sân'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
