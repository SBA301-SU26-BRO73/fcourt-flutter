import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/court_owner.dart';
import '../bloc/owner_detail_cubit.dart';
import '../widgets/owner_decision_dialogs.dart';
import '../widgets/owner_document_image.dart';

/// Chi tiết hồ sơ chủ sân và thao tác duyệt/từ chối. Cần [OwnerDetailCubit]
/// phía trên trong cây widget. Khi duyệt xong, đóng màn hình và trả về
/// [OwnerDecision] cho màn danh sách.
class OwnerApprovalDetailScreen extends StatelessWidget {
  const OwnerApprovalDetailScreen({
    super.key,
    this.imageBuilder = defaultOwnerImageBuilder,
  });

  final OwnerImageBuilder imageBuilder;

  void _onStateChanged(BuildContext context, OwnerDetailState state) {
    final error = state.actionError;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final decision = state.decision;
    if (decision == null) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(decision);
    } else {
      // Mở trực tiếp bằng URL: không có màn danh sách để báo kết quả.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision.type == OwnerDecisionType.approved
                ? 'Đã duyệt hồ sơ'
                : 'Đã từ chối hồ sơ',
          ),
        ),
      );
    }
  }

  Future<void> _approve(BuildContext context, CourtOwner owner) async {
    final cubit = context.read<OwnerDetailCubit>();
    final note = await showApproveOwnerDialog(context, owner);
    if (note == null) return;
    await cubit.approve(reason: note);
  }

  Future<void> _reject(BuildContext context, CourtOwner owner) async {
    final cubit = context.read<OwnerDetailCubit>();
    final reason = await showRejectOwnerDialog(context, owner);
    if (reason == null) return;
    await cubit.reject(reason);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OwnerDetailCubit, OwnerDetailState>(
      listenWhen: (previous, current) =>
          previous.actionError != current.actionError ||
          previous.decision != current.decision,
      listener: _onStateChanged,
      builder: (context, state) {
        final owner = state.owner;
        return PopScope(
          canPop: !state.submitting,
          child: Scaffold(
            appBar: AppBar(title: const Text('Chi tiết hồ sơ chủ sân')),
            body: switch (state.status) {
              OwnerDetailStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              OwnerDetailStatus.failure => _LoadError(
                message: state.message ?? '',
                onRetry: context.read<OwnerDetailCubit>().load,
              ),
              OwnerDetailStatus.loaded when owner != null => _OwnerDetailBody(
                owner: owner,
                submitting: state.submitting,
                imageBuilder: imageBuilder,
              ),
              OwnerDetailStatus.loaded => const SizedBox.shrink(),
            },
            bottomNavigationBar:
                owner != null && owner.isPending && state.decision == null
                ? _DecisionBar(
                    submitting: state.submitting,
                    onApprove: () => _approve(context, owner),
                    onReject: () => _reject(context, owner),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _OwnerDetailBody extends StatelessWidget {
  const _OwnerDetailBody({
    required this.owner,
    required this.submitting,
    required this.imageBuilder,
  });

  final CourtOwner owner;
  final bool submitting;
  final OwnerImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = owner.createdAt;
    final legal = owner.legalDocuments;
    final courtImages = owner.courtImages;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (submitting) const LinearProgressIndicator(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.fullName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Chip(label: Text(_statusLabel(owner.status))),
                if (!owner.isPending)
                  Text(
                    'Hồ sơ không còn ở trạng thái chờ duyệt.',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                const Divider(height: 24),
                _InfoRow(label: 'Email', value: owner.email),
                _InfoRow(label: 'Số điện thoại', value: owner.phone),
                _InfoRow(
                  label: 'Ngày đăng ký',
                  value: created == null
                      ? null
                      : DateFormat('dd/MM/yyyy HH:mm').format(created),
                ),
                const _InfoRow(
                  label: 'Số CCCD',
                  value: null,
                  emptyText: 'Chưa có trong API, xem ảnh giấy tờ bên dưới',
                ),
                const _InfoRow(
                  label: 'Tên / mã số doanh nghiệp',
                  value: null,
                  emptyText: 'Chưa có trong API, xem ảnh giấy tờ bên dưới',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Giấy phép kinh doanh / CCCD', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (legal.isEmpty)
          const Text('Chủ sân chưa tải lên giấy tờ pháp lý.')
        else
          for (final (index, doc) in legal.indexed)
            OwnerDocumentThumbnail(
              key: ValueKey('legal-${doc.id}'),
              url: doc.url,
              title: 'Giấy tờ pháp lý ${index + 1}',
              imageBuilder: imageBuilder,
            ),
        if (courtImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Ảnh sân', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final (index, doc) in courtImages.indexed)
            OwnerDocumentThumbnail(
              key: ValueKey('court-${doc.id}'),
              url: doc.url,
              title: 'Ảnh sân ${index + 1}',
              imageBuilder: imageBuilder,
            ),
        ],
      ],
    );
  }
}

String _statusLabel(OwnerStatus status) => switch (status) {
  OwnerStatus.pendingApproval => 'Chờ duyệt',
  OwnerStatus.active => 'Đã duyệt',
  OwnerStatus.rejected => 'Đã từ chối',
  OwnerStatus.locked => 'Đã khóa',
  OwnerStatus.inactive => 'Ngưng hoạt động',
};

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.emptyText = 'Chưa cập nhật',
  });

  final String label;
  final String? value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value ?? emptyText,
              style: value == null
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.submitting,
    required this.onApprove,
    required this.onReject,
  });

  final bool submitting;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: colors.error),
                onPressed: submitting ? null : onReject,
                icon: const Icon(Icons.close),
                label: const Text('Từ chối'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: submitting ? null : onApprove,
                icon: const Icon(Icons.check),
                label: const Text('Duyệt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
