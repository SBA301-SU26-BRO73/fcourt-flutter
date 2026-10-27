import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:gal/gal.dart';

import '../../domain/entities/booking_ticket.dart';
import '../../domain/entities/payment_checkout.dart';
import '../../domain/repositories/ticket_repository.dart';

class TicketGallerySaver implements TicketSaver {
  @override
  Future<void> save(BookingTicket ticket) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        throw const PaymentFailure('Vui lòng cho phép lưu vé vào thư viện ảnh');
      }
      await Gal.putImageBytes(
        await renderTicketPng(ticket),
        name: 'fcourt-ticket-${ticket.bookingCode}',
      );
    } on PaymentFailure {
      rethrow;
    } on GalException catch (e) {
      throw PaymentFailure(
        e.type == GalExceptionType.accessDenied
            ? 'Vui lòng cho phép lưu vé vào thư viện ảnh'
            : 'Không lưu được vé. Kiểm tra dung lượng rồi thử lại.',
      );
    } catch (_) {
      throw const PaymentFailure(
        'Chưa lưu được vé. Vui lòng thử lại trên Android.',
      );
    }
  }
}

Future<Uint8List> renderTicketPng(BookingTicket ticket) async {
  final lines = [
    'FCOURT · VÉ ĐẶT SÂN',
    ticket.branchName,
    ticket.courtName,
    '${ticket.date} · ${ticket.slots.join(' • ')}',
    'Mã đơn: ${ticket.bookingCode}',
    'Mã check-in: ${ticket.checkInCode}',
  ];
  final painters = <TextPainter>[];
  for (var i = 0; i < lines.length; i++) {
    final painter = TextPainter(
      text: TextSpan(
        text: lines[i],
        style: TextStyle(
          color: const Color(0xFF102A26),
          fontFamily: 'Roboto',
          fontSize: i == 0 ? 28 : 24,
          fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 600);
    painters.add(painter);
  }
  final height =
      80 + 600 + painters.fold<double>(0, (sum, p) => sum + p.height + 16);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 680, height),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  double y = 32;
  for (final painter in painters) {
    painter.paint(canvas, Offset(40, y));
    y += painter.height + 16;
  }
  final codec = await ui.instantiateImageCodec(ticket.png);
  final frame = await codec.getNextFrame();
  canvas.drawImageRect(
    frame.image,
    Rect.fromLTWH(
      0,
      0,
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    ),
    Rect.fromLTWH(40, y, 600, 600),
    Paint()..filterQuality = FilterQuality.none,
  );
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(680, height.ceil());
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const PaymentFailure('Chưa xuất được ảnh vé');
      return bytes.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
    frame.image.dispose();
    codec.dispose();
    for (final p in painters) {
      p.dispose();
    }
  }
}
