import 'package:flutter/material.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/command_key.dart';
import '../domain/check_in_failure.dart';
import '../domain/schedule.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/widgets/wp3b_widgets.dart';

class CheckInDialog extends StatefulWidget {
  const CheckInDialog({
    super.key,
    required this.repository,
    required this.code,
    this.manual = false,
  });
  final OperationsRepository repository;
  final String code;
  final bool manual;
  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  TicketPreview? _preview;
  String? _error;
  bool _busy = true;
  bool _submitted = false;
  bool _done = false;
  final _key = newCommandKey();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.repository.preview(widget.code);
      if (mounted) setState(() => _preview = value);
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || _done) return;
    setState(() {
      _busy = true;
      _submitted = true;
      _error = null;
    });
    try {
      final bookingId = await widget.repository.checkIn(
        widget.code,
        _key,
        manual: widget.manual,
      );
      if (bookingId != _preview?.bookingId) {
        throw const UnknownFailure(
          'Kết quả nhận sân không khớp vé đã kiểm tra',
        );
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      final p = _preview!;
      if (!p.offline) {
        // Online: một hộp xác nhận duy nhất, kết quả báo bằng thông báo ngắn.
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Nhận sân thành công · ${p.name} · ${p.courtName}'),
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Wp3bDialog(
          icon: Icons.check_circle_outline,
          tone: context.fc.success,
          title: 'HỢP LỆ (OFFLINE)',
          content: _TicketBlock(
            preview: p,
            note: 'Đã ghi trên máy này. Đang chờ đối soát máy chủ.',
          ),
          actions: [
            Wp3bAction(
              'Hoàn tất nhận sân',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final failed = _error != null;
    return PopScope(
      canPop: !_busy,
      child: Wp3bDialog(
        icon: failed ? Icons.error_outline : Icons.verified_outlined,
        tone: failed ? context.fc.danger : null,
        title: failed ? 'Chưa thể nhận sân' : 'Xác nhận nhận sân',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(bottom: Gap.md),
                child: LinearProgressIndicator(),
              ),
            if (_preview case final p?) _TicketBlock(preview: p),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: Gap.md),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_submitted && failed)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Text(
                  'Chưa rõ kết quả? Thử lại cùng lệnh để đối soát, không quét lại vé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
        actions: [
          if (_preview == null)
            Wp3bAction('Kiểm tra lại', onPressed: _busy ? null : _load),
          if (_preview != null)
            Wp3bAction(
              _submitted ? 'Thử lại lệnh nhận sân' : 'Xác nhận nhận sân',
              onPressed: _busy || _done ? null : _confirm,
            ),
          Wp3bAction(
            'Đóng',
            kind: Wp3bActionKind.text,
            onPressed: _busy ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

class _TicketBlock extends StatelessWidget {
  const _TicketBlock({required this.preview, this.note});
  final TicketPreview preview;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final p = preview;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wp3bInfoBlock(
          children: [
            Wp3bInfoRow('Khách', p.name),
            Wp3bInfoRow('Sân', p.courtName),
            Wp3bInfoRow('Giờ', '${displayDate(p.date)} · ${p.start}–${p.end}'),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.md),
            child: Text(
              note!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
