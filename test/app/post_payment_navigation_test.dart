import 'package:fcourt/app/post_payment_navigation.dart';
import 'package:fcourt/features/payment/domain/entities/payment_checkout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<GoRouter> pump(WidgetTester tester, void Function(BuildContext) action) async {
    final router = GoRouter(
      initialLocation: '/payments/receipt',
      routes: [
        GoRoute(
          path: '/payments/receipt',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => action(context),
              child: const Text('done'),
            ),
          ),
        ),
        GoRoute(path: '/bookings', builder: (_, _) => const Text('list')),
        GoRoute(path: '/bookings/:id', builder: (_, s) => Text('detail ${s.pathParameters['id']}')),
        GoRoute(path: '/payments/ticket', builder: (_, _) => const Text('ticket')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('done'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('ticket opens over the bookings list so Back does not exit', (tester) async {
    final router = await pump(
      tester,
      (c) => showTicketOverBookings(c, const CheckoutArguments(bookingId: 7)),
    );
    expect(find.text('ticket'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('booking detail opens over the bookings list so Back does not exit', (tester) async {
    final router = await pump(tester, (c) => showBookingOverList(c, 7));
    expect(find.text('detail 7'), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
  });
}
